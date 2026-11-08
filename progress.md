# Progress

Process changed by user on 2026-11-08: mentoring/quiz flow paused; full design drafted in design.md for review.
2026-11-08: user removed admin role/portal; design, decisions and requirements updated (roles from IdP groups).

Steps 1-7: drafted in design.md (awaiting user review).
Step 8 (final review, 10x scale, mock interview, failure-injection drill): not started.

## Weak spots
None assessed (no quiz answers yet). Candidate topic to test later: who controls access when there is no admin (IdP dependency).

2026-11-08: Project skeleton created (no application code): backend/ (Rails 8 API, PostgreSQL, DBs acme_salary_development/test created), frontend/ (React + Vite, /api proxied to Rails :3000). Both build/boot cleanly.

2026-11-08: Docker dev setup added (docker-compose.yml, backend/frontend Dockerfile.dev), tested: db healthy, Rails /up 200, Vite 200, proxy reaches Rails. Removed unusable generated Rails credentials (dev needs none; production will use SECRET_KEY_BASE env).
