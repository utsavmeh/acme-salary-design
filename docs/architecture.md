# Architecture

Diagrams are Mermaid, so GitHub draws them. They describe the code as built; `design.md` explains the reasoning and the trade-offs.

## 1. Containers

One Rails API, one PostgreSQL database, one React app. No queue, cache or search engine: at 10,000 employees they would add failure modes and nothing else.

```mermaid
flowchart LR
    hr["HR manager / rate manager / auditor<br/>(web browser)"]
    ops["System operator<br/>(terminal)"]

    subgraph app["ACME Salary Management"]
        spa["React app (Vite)<br/>screens, no business rules"]
        api["Rails API<br/>authentication, roles, rules, reports, audit"]
        cli["Rake tasks<br/>users:*  seed:demo  perf:reports"]
        db[("PostgreSQL<br/>salary data, users, audit log")]
    end

    hr -->|HTTPS| spa
    spa -->|"JSON over /api, bearer token"| api
    ops --> cli
    api --> db
    cli --> db
```

Key points
- The browser only talks to the React app. In development Vite forwards `/api` to Rails, so there is one origin and no CORS setup.
- Operators manage accounts with rake tasks, not screens. Those actions are audited as `cli:<operator>`.
- Rails is the only thing that writes to the database, so every rule (net = gross - deductions, append-only history, audit) lives in one place.

## 2. Backend components

Controllers stay thin: check the role, call one service, audit, render. The rules sit in services and models.

```mermaid
flowchart TB
    subgraph web["Controllers (HTTP, roles)"]
        sessions["Sessions / Passwords / Me"]
        employees["Employees / Assignments / Exports"]
        salary["SalaryRecords"]
        rates["ExchangeRates"]
        reports["Reports"]
        imports["Imports"]
        auditc["AuditEvents"]
    end

    subgraph services["Services (rules)"]
        login["Auth::Login<br/>Auth::Tokens"]
        search["EmployeeSearch<br/>EmployeeCsv, CsvSanitizer"]
        writer["SalaryRecordWriter"]
        ratebook["RateBook<br/>Reports::Conversion"]
        rep["Reports::PaySummary, TopPaid,<br/>Hikes, DataQuality"]
        imp["Imports::Parser, RowValidator,<br/>Stage, Commit, Reconciliation"]
        audit["AuditLog<br/>(hash chain)"]
        manager["Users::Manager"]
    end

    subgraph models["Models"]
        m["User, Employee, Assignment,<br/>SalaryRecord, DeductionLine,<br/>ExchangeRate, ImportBatch, ImportRow,<br/>AuditEvent"]
    end

    sessions --> login
    employees --> search
    salary --> writer
    rates --> ratebook
    reports --> rep
    rep --> ratebook
    imports --> imp
    auditc --> audit

    login --> audit
    writer --> audit
    imp --> audit
    manager --> audit
    employees --> audit
    reports --> audit
    rates --> audit

    login --> m
    search --> m
    writer --> m
    ratebook --> m
    rep --> m
    imp --> m
    manager --> m
    audit --> m
```

Rules that every path obeys
- **Roles are checked on the server** in each controller (`require_role!`); hiding a tab in the UI is only a convenience.
- **Audit and action share one database transaction**, so there is never an action without its log line, or a log line for an action that rolled back.
- **Salary records and exchange rates are append-only.** A correction is a new version; `readonly?` blocks updates and deletes in the models.
- **Money is a decimal with a currency, never a float**, and is sent to the browser as a two-decimal string.

## 3. Excel migration

The import is two steps with a human in between, so bad data never reaches the live tables by accident.

```mermaid
sequenceDiagram
    actor HR as HR manager
    participant API as Rails API
    participant Stage as Imports::Stage
    participant DB as PostgreSQL

    HR->>API: upload .csv or .xlsx
    API->>Stage: stage the file
    Stage->>Stage: file already uploaded? (SHA-256)
    Stage->>Stage: parse rows, check each row, check repeats and clashes
    Stage->>DB: save batch + every row as accepted or rejected (nothing loaded yet)
    API-->>HR: counts of accepted and rejected rows

    HR->>API: view rejected rows (JSON or CSV) and reconciliation
    API-->>HR: reasons per row, totals per currency: file = accepted + rejected

    HR->>API: commit (confirm if rows were rejected)
    API->>DB: ONE transaction: employees, department history, salary records, deductions
    alt a row now conflicts
        DB-->>API: abort, nothing loaded
        API-->>HR: 409 with the row number
    else all rows loaded
        API->>DB: audit "import.committed"
        API-->>HR: committed, reconciliation now also shows loaded = accepted
    end
```

## 4. Data model

```mermaid
erDiagram
    EMPLOYEE ||--o{ ASSIGNMENT : "department and title history"
    EMPLOYEE ||--o{ SALARY_RECORD : "pay history"
    SALARY_RECORD ||--o{ DEDUCTION_LINE : has
    IMPORT_BATCH ||--o{ IMPORT_ROW : stages
    IMPORT_BATCH |o--o{ SALARY_RECORD : loaded

    EMPLOYEE {
        string employee_number UK
        string name
        string country
        date hire_date
        string status "active or inactive"
    }
    ASSIGNMENT {
        string department
        string job_title
        date effective_from "unique per employee"
    }
    SALARY_RECORD {
        string currency
        string country
        decimal base_pay
        decimal gross
        decimal net "gross minus deductions"
        date effective_from
        int version "highest wins, unique with employee and date"
        string created_by
    }
    DEDUCTION_LINE {
        string label
        decimal amount
    }
    EXCHANGE_RATE {
        string currency
        int year
        decimal rate_to_usd
        int version "highest wins"
        string reason
        string set_by
    }
    USER {
        string username UK
        string password_digest "bcrypt"
        string_array roles "hr, rate_manager, auditor"
        string status "active or deactivated"
        int failed_attempts
        datetime locked_until
    }
    AUDIT_EVENT {
        datetime occurred_at
        string actor
        string action
        string target_type
        jsonb details "never salary amounts"
        string prev_hash "links to the previous event"
        string event_hash
    }
    IMPORT_BATCH {
        string file_sha256 UK
        string status "staged or committed"
        int accepted_rows
        int rejected_rows
    }
    IMPORT_ROW {
        int row_number
        string status
        jsonb raw
        string_array reasons
    }
```

`EXCHANGE_RATE`, `USER` and `AUDIT_EVENT` are standalone: rates are looked up by currency and year, and the audit log points at its target by type and id rather than by a foreign key, so it survives whatever happens to the target.

## Why this shape

- **Modular monolith, one database:** the work is correctness, security and migration quality, not scale. One transaction can cover an action, its audit entry and its data.
- **History as appended rows:** pay history and rate history are the product. Never editing a row makes "what did we pay in March" always answerable.
- **Thin UI:** the React app never decides a rule, so a second client or a script cannot bypass one.
