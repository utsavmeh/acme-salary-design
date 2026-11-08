# Decisions (format: decision | options | reason)

1. Monthly pay only; frequency field removed | keep many frequencies / monthly only | simpler, comparable; migration rejects non-monthly rows
2. Reports: native currency (single-currency scope only) or USD | any target currency | avoids cross rates
3. SUPERSEDED by 13.
4. Rate setting = separate Rate Manager IdP group | all HR / separate group | fewer people can change money-affecting data
5. Rates versioned, reports use latest, exports stamped with rate version | freeze reports / recompute | reproducible and explainable
6. Multi-year: each amount uses the rate of its own calendar year | single rate / per-year | matches fixed annual rate rule
7. Department and title as effective-dated assignments | on employee only / history | past reports stay correct
8. Hike % computed in native currency | USD / native | no FX noise
9. Salary records immutable; corrections supersede | edit in place / append | history and audit
10. Single PostgreSQL, modular monolith, no warehouse | microservices / warehouse | 10k employees is small
11. SSO with MFA; audit in same transaction, hash-chained | local login / SSO | security priority
12. Process change (by user): step-by-step mentoring paused; full design drafted at once
13. No admin role, no admin portal; roles = IdP groups (salary-hr, salary-rate-manager, salary-auditor), managed by IT in the IdP; app audits role changes seen at login | in-app admin portal / IdP groups / config file | far less to build and secure; control moves to the IdP; requires an IdP (assumption 3)
14. Stack: Ruby on Rails (API mode) backend, React frontend (Vite), PostgreSQL (kept; MySQL rejected) | MySQL / PostgreSQL | MySQL lacks partial unique indexes and DB-level non-overlap checks the design relies on
15. Rule change (by user): skeleton setup allowed, still no application code
