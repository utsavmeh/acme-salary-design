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
- **Access:** no admin role and no admin portal. Roles come from groups in the company sign-in system:
  `salary-hr` (salary data, reports, imports), `salary-rate-manager` (exchange rates), `salary-auditor` (audit log).

## Run with Docker (recommended)

Prerequisite: Docker Desktop (or Docker Engine with the Compose plugin), running.

1. From the project root, build and start everything:
   ```
   docker compose up --build
   ```
   The first run takes a few minutes (it installs gems and npm packages).
   The backend creates and prepares its database automatically on start.
2. Create a development sign-in token (valid 12 hours). Roles come from the groups you list:
   ```
   docker compose exec backend bin/rails "auth:dev_token[me@acme.test,salary-hr salary-rate-manager salary-auditor]"
   ```
3. Open the app, paste the token on the sign-in page:
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

## Run the backend tests

```
docker compose exec backend bundle exec rspec        # with Docker (needs RAILS_ENV=test db: see below)
cd backend && bundle exec rspec                      # without Docker, local PostgreSQL
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
- Signing in: the app verifies a signed token (HS256, secret in `JWT_SECRET`) carrying `email` and `groups`. `JWT_SECRET` is required in
  production. To use the real company sign-in system (OIDC), replace `Auth::TokenVerifier` with a verifier of that provider's public keys;
  nothing else changes.
- Development and test need no Rails credentials file. For production, the secret key
  must come from the `SECRET_KEY_BASE` environment variable, and database settings
  from `DB_*` / `BACKEND_DATABASE_PASSWORD`. No production deployment setup exists yet.
- The passwords in `docker-compose.yml` are for local development only.
- If Rails fails with `ActiveSupport::MessageEncryptor::InvalidMessage`, check whether a
  stray `RAILS_MASTER_KEY` is set in your shell (`env | grep RAILS_MASTER_KEY`).
