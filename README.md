# ACME Salary Management

Web application for HR managers to manage salary data for ACME's 10,000 employees.
Stack: Ruby on Rails (API) + React (Vite) + PostgreSQL.

Design docs: `requirements.md`, `design.md`, `decisions.md`, `open-items.md`, `progress.md`.
Status: backend and frontend implemented. Backend has an RSpec suite (about 200 examples, under 2 seconds);
the frontend has no automated tests by design.

## Project layout

| Path | What it is |
|---|---|
| `backend/` | Rails 8 API (Ruby 3.2.2), PostgreSQL |
| `frontend/` | React app built with Vite |
| `docker-compose.yml` | Development setup: db + backend + frontend |

## What it does

- **Employees and pay:** employees, department/job-title history, monthly salary records in the employee's own currency with
  gross, each deduction and net (net must equal gross minus deductions). Salary records are append-only: a correction is a new version.
- **Reports:** pay summary (by department, country or job title), highest paid, biggest salary increases in a year, data-quality gaps.
  Shown in USD (one fixed rate per currency per calendar year, with the original amounts alongside) or in the original currency
  when the result is a single currency. A missing rate is reported, never guessed.
- **Exchange rates:** versioned, never overwritten, every change has a reason and is audited. Only the rate-manager group may change them.
- **Excel/CSV migration:** upload, row-by-row validation, rejected-rows report, reconciliation totals, then an all-or-nothing commit.
- **Search and CSV export** (audited, protected against spreadsheet formula injection).
- **Audit log:** every view, search, export and change, hash-chained so tampering is detectable. Salary amounts are never copied into it.
- **Access:** username and password sign-in. Three roles: `hr` (salary data, reports, imports), `rate_manager` (exchange rates),
  `auditor` (audit log). There is no admin role and no admin screen: the people who run the system manage accounts from the command
  line (below). Accounts are deactivated, never deleted; five wrong passwords lock an account for 15 minutes; a new or reset account
  gets a one-time password that must be changed at first sign-in; deactivating a user or changing a password ends their sessions at once.

## Run with Docker (recommended)

Prerequisite: Docker Desktop (or Docker Engine with the Compose plugin), running.

1. From the project root, build and start everything:
   ```
   docker compose up --build
   ```
   The first run takes a few minutes (it installs gems and npm packages).
   The backend creates and prepares its database automatically on start.
2. Create your first user. The one-time password is printed once:
   ```
   docker compose exec -e OPERATOR=$(whoami) backend bin/rails "users:create[your.name,hr rate_manager auditor]"
   ```
3. Open the app and sign in with that username and one-time password (you will be asked to choose your own password):
   - Frontend: http://localhost:5173
   - Rails health check: http://localhost:3000/up (should return a green page)
   - PostgreSQL from your machine: `localhost:5433`, user `acme_salary`,
     password `acme_salary_dev`, database `acme_salary_development`
4. Stop: press `Ctrl+C`, or run `docker compose down` (add `-v` to also delete the database data).

Useful commands:
```
docker compose up -d                  # start in the background
docker compose logs -f backend        # follow Rails logs
docker compose exec backend bin/rails console
docker compose exec backend bin/rails db:migrate
docker compose exec backend bin/rails test
docker compose exec frontend npm run build
docker compose exec db psql -U acme_salary acme_salary_development
```
If you change `Gemfile` or `package.json`, rebuild: `docker compose up --build`.
Code changes in `backend/` and `frontend/` are picked up without a rebuild.

How the pieces connect: the browser talks only to the Vite server (port 5173).
Vite forwards every `/api/...` request to Rails (port 3000), so no CORS setup is needed.

## Run without Docker

Prerequisites: Ruby 3.2.2, Node 22+, PostgreSQL running locally.

1. Backend: `cd backend && bundle install && bin/rails db:create db:prepare && bin/rails server`
2. Frontend (second terminal): `cd frontend && npm install && npm run dev`

## Managing user accounts (operators only)

Run from `backend/` (or with `docker compose exec -e OPERATOR=$(whoami) backend` in front). `OPERATOR` is recorded in the audit log.
Roles are `hr`, `rate_manager`, `auditor`, separated by spaces.

```
bin/rails "users:create[asha.rao,hr]"            # prints a one-time password
bin/rails "users:set_roles[asha.rao,hr auditor]"
bin/rails "users:reset_password[asha.rao]"       # forgotten password: prints a new one-time password
bin/rails "users:deactivate[asha.rao]"           # leaves the company; account is kept for the audit trail
bin/rails "users:activate[asha.rao]"
bin/rails "users:unlock[asha.rao]"               # clear a lockout early
bin/rails users:list
```

## Dummy data for trying the app

```
docker compose exec backend bin/rails "seed:demo[10000]"     # or without Docker: cd backend && bin/rails "seed:demo[10000]"
```
Creates made-up employees in 10 countries and 9 departments, each with department/job-title history, a monthly salary history
(yearly raises and some promotions), deductions, and exchange rates for every currency and year, in about 8 seconds. It refuses to run
in production or when employees already exist (to start over: `bin/rails db:schema:load`, which also removes users).
`SEED=7` gives a different data set; the same `SEED` always gives the same data. About 5 active employees get no salary record on
purpose, so the data-quality report has something to show. To clear only the demo data and keep your users, see the SQL below.

```
docker compose exec backend bin/rails runner 'ActiveRecord::Base.connection.execute("TRUNCATE deduction_lines, salary_records, assignments, employees, exchange_rates RESTART IDENTITY CASCADE")'
```

## Run the backend tests

```
docker compose exec -e RAILS_ENV=test backend bash -c "bin/rails db:create db:schema:load && bundle exec rspec"   # with Docker
cd backend && bundle exec rspec                                                                                  # without Docker, local PostgreSQL
```
The suite uses a real PostgreSQL database (the audit chain and the "current salary" queries rely on it), runs in a transaction per
example, needs no network, and takes under 2 seconds. First time without Docker: `cd backend && RAILS_ENV=test bin/rails db:create db:schema:load`.
Code style: `cd backend && bundle exec rubocop`.

## Excel/CSV import format

One row per salary record, header in line 1, `.csv` or `.xlsx`:

| Column | Example | Notes |
|---|---|---|
| employee_number, name | E1, Asha Rao | the same number must always have the same name |
| country, currency | IN, INR | 2-letter and 3-letter codes |
| hire_date, effective_from | 2024-01-31 | YYYY-MM-DD (or real Excel dates); effective_from may not precede hire_date |
| department, job_title | Engineering, Developer | |
| base_pay, gross, net | 1000.50 | plain numbers, at most 2 decimals; net = gross - deductions |
| deductions | `Income tax:100;Pension:50` | optional |
| frequency | monthly | optional; anything other than monthly is rejected |

## Notes and gotchas

- Port 5432 is not used by Docker's database (it uses 5433), so it will not clash with a local PostgreSQL.
- Sessions are signed tokens that last 8 hours. In production set `JWT_SECRET` to a long random value (`openssl rand -hex 64`);
  the app refuses to start without it. Serve the app over HTTPS only.
- Development and test need no Rails credentials file. For production, the secret key
  must come from the `SECRET_KEY_BASE` environment variable, and database settings
  from `DB_*` / `BACKEND_DATABASE_PASSWORD`. No production deployment setup exists yet.
- The passwords in `docker-compose.yml` are for local development only.
- If Rails fails with `ActiveSupport::MessageEncryptor::InvalidMessage`, check whether a
  stray `RAILS_MASTER_KEY` is set in your shell (`env | grep RAILS_MASTER_KEY`).
