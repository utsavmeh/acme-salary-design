# ACME Salary Management: Full Design (v1 draft for review)

Design only. Where requirements were unclear I chose the simplest safe option and listed it under "Assumptions" so you can overrule it.

---
## 1. Requirement changes and open items, closed

| Item | Decision |
|---|---|
| Pay frequency | Monthly only, paid at month end. The "pay frequency" field is removed. Migration rejects any row that is not monthly (with a reason). HR fixes it in Excel and re-imports. |
| Report currency | Two modes. (a) **Native**: allowed only when the result set is one currency (e.g. country = India, shown in INR). (b) **USD**: any scope, using annual rates. No "show in EUR" mode, because that needs cross rates and more rate data. |
| Admin role and portal | **Removed.** No admin role and no user-management screens. Access comes from groups in ACME's identity provider (IdP): `salary-hr`, `salary-rate-manager`, `salary-auditor`. IT adds and removes people there, using the IdP's own approval workflow. The app records the roles it sees at each login and alerts on any change. |
| Who sets exchange rates | A separate **Rate Manager** IdP group (`salary-rate-manager`). Not part of the base HR role. |
| Rate correction vs past reports | Rates are versioned and never overwritten. A correction creates a new version with a mandatory reason. Reports are always computed on the current version. Each exported file carries a stamp with the rate version(s) used, so an old export can be explained and re-run. |
| Multi-year reports | Each amount is converted at the rate of the calendar year it belongs to (a pay month in 2024 uses the 2024 rate). If any needed year/currency rate is missing, the report shows the affected rows as "rate missing" and gives no USD total for them. |
| Department / role | Added as an effective-dated assignment (employee, department, job title, effective_from). Reports use the assignment in force at the report's as-of date. |
| Hike definition | A hike is a salary change where new base pay > previous base pay for the same employee. Percent = (new - old) / old, computed in the native currency, so it needs no exchange rate. Ranking by absolute amount across currencies uses USD, converting old and new with the rate for the hike's year. |

## 2. Reporting questions (initial list)
1. Average (and median, min, max) base pay by department, country, job title, optionally in USD.
2. Highest-paid employee in a department, or in the whole company (USD for cross-country).
3. Biggest hikes in a chosen year: top N by percent, with employee details and old/new pay.
4. Headcount and total monthly payroll cost by country and department.
5. Pay distribution bands (histogram) for a role.
6. Employees with no salary record, or with a currency whose rate is missing (data-quality report).
7. Salary history of one employee.
8. Gross, deductions, net totals by country.

## 3. Estimation
- 10,000 employees x about 5 salary records over their lifetime = ~50,000 rows, plus ~5 deduction lines each = ~250,000 rows. Under 1 GB total.
- Users: ~20-50 HR managers. Peak load below 10 requests/second.
- Audit events: 50 users x ~200 actions/day = ~10,000/day, ~3.6M/year, a few GB over 5 years.
- Conclusion: one relational database is enough. Reports run live in SQL. No warehouse, cache or queue cluster is needed.

## 4. Data model (all money = exact decimal + currency code, never float)
- **employee**: id, employee_number (unique), name, country, hire_date, status. Never deleted.
- **assignment**: employee_id, department, job_title, effective_from (history kept).
- **salary_record**: id, employee_id, currency, base_pay, gross, net, country, effective_from, effective_to (nullable), created_by, created_at, supersedes_id. Records are never updated or deleted. A correction creates a new row that supersedes the old one.
- **deduction_line**: salary_record_id, label, amount. Rule enforced at write: gross - sum(deductions) = net, exactly.
- **exchange_rate**: id, currency, year, rate_to_usd, version, reason, set_by, set_at. New version per change; the latest version wins.
- **app_user**: id, email, last_seen_at. Created automatically at first login, never deleted. Whether a person is active is decided by the IdP, not by a field here.
- **role_snapshot**: user_id, roles seen in the IdP token, seen_at. A new row is written only when the roles differ from the previous login (this is how role changes are audited and alerted).
- **audit_event**: id, time, actor, action (view/search/export/create/change/grant/rate), target type and id, filter or parameters used, result count, source IP. Append-only, each row carries a hash of the previous row (tamper evidence).
- **import_batch / import_row**: batch id, file hash, row number, raw content, status (accepted/rejected), rejection reason.
- **export_job**: id, requested_by, report definition, row count, rate version stamp, file location, expires_at.

Constraints: only one open (effective_to null) salary record per employee; no overlapping date ranges; unique(currency, year, version).

## 5. APIs (REST, JSON, all authenticated; each call checks role and writes audit)
- `GET /employees`, `GET /employees/{id}`: search and filter (name, country, department, title, pay range).
- `GET /employees/{id}/salary-history`
- `POST /employees/{id}/salary-records` (new effective-dated record; uses an Idempotency-Key header so a retry never duplicates)
- `POST /salary-records/{id}/correct`
- `GET /reports/{name}?currency_mode=native|usd&year=...&filters`
- `POST /exports`, `GET /exports/{id}` (async; file link is short-lived and audited)
- `GET/POST /exchange-rates`, `GET /exchange-rates/history` (Rate Manager to write)
- `POST /imports` (upload), `GET /imports/{id}/rejected-rows`, `GET /imports/{id}/reconciliation`, `POST /imports/{id}/commit`
- `GET /me` (current user and roles). There are no user-management endpoints.
- `GET /audit` (viewable only by the `salary-auditor` group, not by plain HR, since the log itself reveals who looked at whom)

## 6. High-level architecture
Browser SPA -> HTTPS load balancer/WAF -> stateless app server (modular monolith: users, salary, rates, reports, import, audit modules) -> PostgreSQL (primary + hot standby). Object storage holds uploaded Excel files and export files (encrypted). Sign-in goes through ACME's identity provider (SSO with MFA); the app reads the user's group claims from the token and maps them to roles. No passwords are stored by the app. A background worker (same codebase) runs imports and exports.

Why a monolith: 10,000 employees is tiny; microservices would add failure modes without benefit.

## 7. Deep dives
- **Authorization**: server-side checks on every endpoint. A user with no salary group gets a 403 on everything, including a view of an empty page. Roles are read from the token and re-checked at every token refresh (access tokens last about 15 minutes), so removing someone from a group ends their access within minutes.
- **Audit**: written in the same transaction as the action, so no action without a log entry. View audits record the filter used and the result count. Exports are logged with row count. The log is shipped daily to write-once storage.
- **Excel migration**: (1) upload file, store it, compute its hash; (2) parse into staging rows; (3) validate each row (required fields, known country/currency, monthly only, decimal money, gross-deductions=net, dates, employee match, duplicates inside the file); (4) produce accepted and rejected lists with reasons; (5) reconciliation: per file and currency, row count and sum of gross/net in Excel vs staging vs final; (6) HR reviews, then commits in one transaction. Re-uploading the same file hash is blocked, so a double import cannot happen. Nothing partial reaches live tables. Rejected rows are fixed in Excel and re-imported as a new batch.
- **Concurrent edits**: optimistic locking with a version number on records. The second saver gets a conflict message.
- **Rate lookup**: a single function: (currency, year) -> latest version or "missing". Reports never fall back to a nearby year.
- **Exports**: size cap, async job, link expires in 24h, watermark with user and time, every download audited. Dangerous cells (starting with = + - @) are escaped to stop spreadsheet formula injection.

## 8. Failure modes and edge cases
- Duplicate submit / retry: idempotency key; unique constraints.
- Two HR users edit the same employee: version check, second gets conflict.
- Backdated salary change: allowed; system rebuilds the effective ranges and rejects overlaps. Audited.
- Missing rate: report flags rows, never guesses. Data-quality report lists all gaps.
- Rate corrected after a report was exported: old export keeps its stamp; the new run uses the new version; the diff is explainable from the rate history.
- Employee moves country/currency: new salary record with the new currency; history stays in the old one.
- Bad Excel data: rejected with reason; never partially loaded.
- Someone at IT adds themselves (or a friend) to a salary group: the app cannot block it, but the next login writes a role_snapshot row and fires an alert to security and the HR head. The IdP's own change log and approval workflow are the primary control.
- Departing HR user: removed from the IdP group (or disabled in the IdP); access ends at the next token refresh (minutes); audit history stays.
- IdP outage: nobody can sign in. Already-signed-in sessions end at token expiry. Accepted, because salary access is not time-critical.
- Stolen session / abuse: short sessions, MFA, rate limits, alert on unusual export volume or after-hours bulk viewing.
- Database or app server down: standby takes over; the app shows a clear outage page; no writes are accepted while the primary is unavailable (consistency over availability).
- Export worker crashes: job is retried; output is written to a temp name and renamed only when complete.

## 9. Production readiness
- **Security**: SSO + MFA; least privilege; TLS everywhere; database and storage encrypted at rest; secrets in a vault; field-level encryption for pay columns with keys in a KMS; dependency scanning; annual penetration test; no salary data in logs, URLs, or error messages; non-production environments get only synthetic data.
- **Monitoring and alerting**: error rate, latency, job failures; security alerts (role changes seen at login, rate changes, bulk exports, repeated failed logins, audit-chain break); backup success alert; reconciliation-mismatch alert.
- **Deployment**: infrastructure as code; CI with tests and migration checks; staged rollout (staging, then production); database migrations are backward compatible so the app can roll back without a database rollback; a feature flag around risky changes.
- **Backup and recovery**: continuous WAL archiving (point-in-time restore) plus nightly full backup, encrypted, copied to a second region. Targets: RPO 15 minutes, RTO 4 hours. Restore drill each quarter into an isolated environment, checked by row counts and a salary-total reconciliation.
- **Data privacy**: purpose limitation (HR only); retention policy decided with Legal (the system itself never deletes pay history); access reviews every quarter; audit log is itself access-controlled.

## 10. Assumptions I made (please confirm or overrule)
1. All HR managers can see all countries (no country scoping). Easy to add later via a country filter on roles.
2. A salary record holds monthly figures (gross, deductions, net) per effective period, not a separate payslip for every month.
3. **Now critical:** ACME has a company identity provider with MFA and groups, and IT will manage the three salary groups there with an approval step. Without it, this simplification does not work.
4. Department and job title exist in the Excel files or can be supplied.
5. Retention period and any data-residency law per country are not yet known; Legal must answer.

## 11. Not done yet
Final review, scale-it-10x discussion, mock interview and failure-injection drill. Run these once you've reviewed this document.

---
## 12. Implementation notes (what was built, and where it differs from the design above)

Built: sections 1-8 for the backend (Rails API + PostgreSQL) and a React frontend. Differences, all on purpose to keep it simple:

| Design said | Implementation |
|---|---|
| Sign-in through the company IdP (OIDC) | Verifies a signed HS256 token with `email` and `groups` claims. Swapping in the IdP's public-key verification is one class (`Auth::TokenVerifier`). |
| `effective_to` on salary records, partial unique index | No `effective_to`: a record is in force until the next one starts. Corrections are versions of the same date (`unique(employee, effective_from, version)`), so overlaps cannot exist. |
| Idempotency-Key header | A repeated create for the same employee and date answers 409. Same safety, no key table. |
| Async export jobs with expiring links | Synchronous CSV (10,000 rows is small). Still audited, and formula-injection safe. |
| 8 reporting questions | 4 reports cover the agreed questions: pay summary (average/lowest/highest/headcount/total by department, country, title), top paid, hikes, data quality. Distribution bands and per-employee history are served by the employee screens. |
| Audit entries for salary changes | They record what changed, not the amounts, so auditors cannot read pay through the log. |
| Second-admin approval, `app_user`, `role_grant` | Removed with the admin role. `role_snapshot` records roles seen at login and audits any change. |

Not built (operations, to do before going live): backups and restore drills, deployment pipeline and monitoring/alerts, rate limiting,
field-level encryption of pay columns, data retention rules, country scoping of HR users, real IdP connection.
Brakeman reports no code issues; it notes that Ruby 3.2 and Rails 8.0 are end-of-life, so upgrade before production.
