# ACME Salary Management

Web application for HR managers to manage salary data for ACME's 10,000 employees.
Stack: Ruby on Rails (API) + React (Vite) + PostgreSQL.

Design docs: `requirements.md`, `design.md`, `decisions.md`, `open-items.md`, `progress.md`.
Status: project skeleton only. There is no application code yet.

## Project layout

| Path | What it is |
|---|---|
| `backend/` | Rails 8 API (Ruby 3.2.2), PostgreSQL |
| `frontend/` | React app built with Vite |
| `docker-compose.yml` | Development setup: db + backend + frontend |

## Run with Docker (recommended)

Prerequisite: Docker Desktop (or Docker Engine with the Compose plugin), running.

1. From the project root, build and start everything:
   ```
   docker compose up --build
   ```
   The first run takes a few minutes (it installs gems and npm packages).
   The backend creates and prepares its database automatically on start.
2. Open the app:
   - Frontend: http://localhost:5173
   - Rails health check: http://localhost:3000/up (should return a green page)
   - PostgreSQL from your machine: `localhost:5433`, user `acme_salary`,
     password `acme_salary_dev`, database `acme_salary_development`
3. Stop: press `Ctrl+C`, or run `docker compose down` (add `-v` to also delete the database data).

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

## Notes and gotchas

- Port 5432 is not used by Docker's database (it uses 5433), so it will not clash with a local PostgreSQL.
- Development and test need no Rails credentials file. For production, the secret key
  must come from the `SECRET_KEY_BASE` environment variable, and database settings
  from `DB_*` / `BACKEND_DATABASE_PASSWORD`. No production deployment setup exists yet.
- The passwords in `docker-compose.yml` are for local development only.
- If Rails fails with `ActiveSupport::MessageEncryptor::InvalidMessage`, check whether a
  stray `RAILS_MASTER_KEY` is set in your shell (`env | grep RAILS_MASTER_KEY`).
