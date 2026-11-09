# ACME Salary Management: Requirements

Version 2 · November 9, 2026

## Goal

Replace the Excel files that hold salary data for ACME's 10,000 employees across several countries with a secure web application. HR managers use it as the trusted record of pay and to answer questions about how the organisation pays its people.

## Users

- **HR managers:** view and manage salary data, run reports, import data.
- **Rate managers:** set the yearly exchange rates.
- **Auditors:** read the audit log, nothing else.
- **System operators:** create and manage accounts from the command line. They have no screens.
- Employees do not use the system.

## Scope and features

1. **Salary records.** Monthly pay only. Base pay, currency, country and effective date, in the employee's own currency. Department and job title are kept as history, so old reports show the department of the time.
2. **Deductions.** Gross, each deduction and net are recorded, and net must equal gross minus deductions. Nothing is calculated.
3. **Salary history.** Records are never edited or deleted. A correction is a new version.
4. **Currency.** Reports show USD, or the original amount when the result is a single currency. USD uses one fixed rate per currency per calendar year. Rates are versioned, each change needs a reason and is audited. A correction affects new reports only; exports name the rate versions used. A multi-year report uses each year's own rate. A missing rate is reported, never guessed, and original amounts always sit beside USD.
5. **Excel migration.** Row-by-row validation, a rejected-rows report with reasons, totals reconciled per currency, and an all-or-nothing load. The same file cannot be loaded twice.
6. **Reporting.** Pay summary by department, country or job title; highest paid; biggest salary increases in a year with percentage and employee details; data-quality gaps.
7. **Search, filter, export.** CSV export is audited.
8. **Security.** Username and password, with lockout after repeated failures. Roles limit who sees salary data. Accounts are deactivated, never deleted. A tamper-evident audit log records views, searches, exports, changes, sign-ins and account changes, and never holds salary amounts.
9. **Reliability.** Regular backups with a tested restore (to be built before go-live).

## Deliberately left out, and why

- **Payroll and moving money:** bank integrations and legal liability; mature providers exist.
- **Tax and country-specific pay rules:** they differ by country and change often, and a wrong calculation harms people. Deductions are recorded, not calculated.
- **Employee access:** a second user type and a much larger security surface.
- **Reimbursements, leave, attendance, benefits:** separate domains.
- **Live exchange rates:** fixed yearly rates keep reports reproducible.
- **Admin portal:** operators manage accounts by command line; an admin screen is a high-value attack target.
- **Mobile app:** the requirement is web-based.

## Principles and known gaps

Security and auditability come before features; at 10,000 employees correctness matters more than scale. Not yet built: multi-factor sign-in, per-address login throttling, backups.
