# Performance notes

Short version: at 10,000 employees every screen answers in about a second or less, the number of SQL queries per request is constant (no N+1), and the design deliberately stays simple. This page records what was measured, what was decided and why, where the limits are, and a defect the measurements caught.

## Load we designed for

| | Estimate | Loaded in the demo data |
|---|---|---|
| Employees | 10,000 | 10,000 |
| Salary records (history) | about 50,000 | 58,195 |
| Deduction lines | about 150,000 | 145,374 |
| Users | 20 to 50 | 1 |
| Audit events | about 10,000 a day (50 users, 200 actions each), about 3.6 million a year | 45 |

Peak traffic is a handful of requests a second. One PostgreSQL database is enough.

## Measured results

Repeat with `bin/rails "seed:demo[10000]"` then `bin/rails perf:reports` (`lib/tasks/perf.rake`).

Setup: Docker on a laptop (development mode, so slower than production), PostgreSQL 16, Ruby 3.2.2, 2026-11-09. Each case runs once to warm up, then three times; the median is shown. The task runs outside Rails' request wrapper, so the query cache is off and every number includes real database time.

| Case | Time | SQL queries |
|---|---|---|
| Report: pay summary by department (USD) | 613 ms | 4 |
| Report: pay summary by country (USD) | 571 ms | 4 |
| Report: top 10 highest paid (USD) | 542 ms | 4 |
| Report: biggest hikes 2025 (by percent) | 1,010 ms | 4 |
| Report: biggest hikes 2025 (by USD amount) | 887 ms | 4 |
| Report: data quality | 569 ms | 5 |
| Search by name, first 25 rows | 7 ms | 2 |
| Search by department, first 25 rows | 11 ms | 2 |
| CSV export of all 10,000 employees | 995 ms | 4 |
| Audit log write | 2.1 ms per event | n/a |
| Loading 10,000 employees with the seed task | about 7 s (one run) | n/a |
| Whole backend test suite (239 examples) | about 3 s | n/a |

Reading the table
- **Query counts stay at 2 to 5 whatever the data size.** Related rows are loaded in bulk (`includes`), never one by one.
- **About 0.4 s of each report is Ruby** building objects and doing the arithmetic (measured separately with the query cache on); the rest is the database.
- Searches return one page (25 rows, capped at 100). A name search matches text anywhere in the name, which cannot use an index, so it scans the employees table; that takes a few milliseconds at 10,000 rows but is one more thing to revisit at 10x (a trigram index would fix it).

## A defect the measurements caught

The first version of the "current salary of each employee" lookup used two correlated subqueries. On the 10,000-employee data PostgreSQL estimated one matching row, chose a nested loop, and scanned the employees table once for every salary record: `EXPLAIN ANALYZE` showed 49.8 million rows discarded and the query alone took about 5 s. Pay reports took 3.4 to 4.2 s.

Fix: pick each employee's latest record in one pass with `SELECT DISTINCT ON (employee_id) ... ORDER BY employee_id, effective_from DESC, version DESC`. Same result (the existing specs for it still pass), and the pay reports dropped to about 0.55 to 0.6 s.

Lesson, and why `perf:reports` exists: an early quick timing looked fine because it ran inside `rails runner`, which turns the query cache on, so repeat runs skipped the database. Timings must be taken with the cache off, and the query count watched.

## Decisions and trade-offs

| Decision | Why | Cost |
|---|---|---|
| Reports are computed in Ruby over the current salary rows, not in SQL | Easy to read and to test with small fixtures. USD conversion with a per-year rate and "missing rate is reported" is simple rule code, awkward in SQL. 10,000 rows is small. | Time and memory grow linearly with employees (see 10x below). |
| One database, no cache, queue or search engine | Nothing here needs them at this size; fewer parts to fail. | Add them only when a measurement says so. |
| Salary history as appended rows with a version | Past pay is always answerable. A unique index on (employee, date, version) makes concurrent edits safe. | A few more rows. |
| Pagination (default 25, maximum 100) | Keeps list screens constant-time and the response small. | Exports are the only way to get everything. |
| CSV export runs inside the request | Simple, and 10,000 rows takes about 1 s. | Ties up a web worker for that second. |
| Audit write shares the action's transaction and takes a lock | The hash chain has no forks and an action never lacks its log line. | Audit writes happen one at a time: about 2 ms each, so a ceiling of roughly 500 a second against a need of about 0.1 a second. |
| Seed and import use bulk inserts | 10,000 employees load in seconds instead of minutes. | Bulk inserts skip model callbacks, so the data is built to satisfy the rules itself (checked by SQL after loading). |
| Money as exact decimals, sent as strings | No rounding drift in totals. | Slightly slower than floats, irrelevant here. |

## Limits and what to do at 10 times the size (100,000 employees)

Everything above grows roughly in line with the data. These are extrapolations, not measurements: if growth is linear, at 100,000 employees pay reports would take about 5 to 6 seconds and hikes and exports about 10 seconds, with memory use that matters. The plan, in order of payoff:

1. **Move the aggregation into SQL.** `GROUP BY` over the current-record query for summaries and top-N; use the `LAG()` window function for hikes. This removes loading every record into Ruby.
2. **Keep a `current_salaries` materialised view** (refreshed when a record is added) so reports read one small table.
3. **Make exports asynchronous** and stream the file to storage, so no web worker is held.
4. **Add a read replica** for reports if they start to compete with data entry.
5. **Partition the audit log by month** (it grows about 3.6 million rows a year at today's rate) and archive old months.

None of this is needed at 10,000 employees, which is why it is not built.
