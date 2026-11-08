# ACME Salary Management System: Requirements

Draft v1 · November 7, 2026

## Goal

Replace the Excel files that hold salary data for ACME's 10,000 employees across multiple countries with a secure web application. HR managers use it to keep salary data as a trusted system of record and to answer questions about how the organization pays its people.

## Users

- **HR managers (multiple):** view and manage salary data.
- **IT / identity team (outside the app):** manages who belongs to the access groups in the company identity provider. They are not users of this system and have no screens in it.
- **Employees:** do not use the system.

## Scope and features

1. **Salary records.** Per employee: base pay, currency, country, pay frequency and effective dates, stored in the original currency.
2. **Deductions.** Gross pay, each deduction and net pay are stored as recorded data. The system does not calculate tax.
3. **Salary history.** Every change is kept, so past pay can be reviewed.
4. **Multi-currency with USD reporting.** Pay is stored in each employee's currency and reported in USD. Each currency has one fixed rate per calendar year (January to December), set by an authorised user. Rates are kept as a history and never overwritten, and every change is audited. Reports show the rate used and always show original amounts next to USD. If a rate is missing, the report says so instead of guessing.
5. **Excel migration.** A one-time import with row-level validation, a report of rejected rows and reasons, and a way to reconcile totals against the original files.
6. **Reporting.** Answers to questions about how the organization pays people, for example by country, department and role.
7. **Search, filter and export.**
8. **Security and access.** Authentication for every user through the company identity provider. Role-based permissions come from identity-provider groups (no admin portal). Salary data visible only to authorised users. Users are deactivated, never deleted. An audit log records who viewed or changed what, including rate changes and role changes seen at login.
9. **Reliability.** Regular backups, with a tested way to restore.

## Deliberately left out, and why

- **Running payroll and moving money.** It brings bank integrations and legal liability, and mature providers already do it.
- **Tax calculation and statutory compliance.** Rules differ by country and change often, and a wrong calculation harms real people. Deductions are recorded, not calculated.
- **Country-specific pay rules.** Same reasoning as tax.
- **Employee access or self-service.** It adds a second user type and a much larger security surface.
- **Reimbursements, leave, attendance and benefits.** These are separate domains with their own workflows.
- **Live or market exchange rates.** Fixed annual rates keep reports reproducible and avoid an external dependency.
- **Admin portal and in-app user management.** Access groups are managed in the company identity provider; building our own would add a screen set, approval flow and a high-value attack target.
- **Mobile app.** The requirement is web-based.

## Constraints and principles

- Salary data is highly sensitive, so security and auditability take priority over features.
- At 10,000 employees, scale is not the challenge. Correctness, security and migration quality are.
- Amounts are always stored with their currency, never as bare numbers.

## Open items to settle

- The concrete list of reporting questions the system must answer.
- Who may set exchange rates (proposed: a separate identity-provider group).
- How a rate correction affects reports that were already run.
- How reports spanning more than one calendar year choose rates.
