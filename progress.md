# Progress

2026-11-08: user paused the mentoring flow; full design drafted (design.md), admin role removed, stack fixed (Rails API, React, PostgreSQL), Docker dev setup done.
2026-11-08: implementation done in small commits (see `git log`): models, auth and roles, audit chain, employees, salary history/corrections,
exchange rates, reports, export, audit API, Excel/CSV import, React frontend. Backend: ~200 RSpec examples passing, RuboCop clean, Brakeman: no code issues.

2026-11-08: sign-in changed to username/password (user decision): User model, login with lockout, password change, session tokens, CLI account management; frontend updated. Backend now 239 RSpec examples.

2026-11-09: assessment gaps closed: requirements rewritten (one page), architecture diagrams (docs/architecture.md), performance notes and `perf:reports` task (docs/performance.md), CI moved to the repo root with RSpec and a frontend job. Measuring found a slow current-salary query (3.4 s at 10,000 employees); fixed with DISTINCT ON (0.6 s).

Not done: operations items listed in design.md section 12; step 8 (final review, scale-it-10x, mock interview, failure-injection drill).

## Weak spots
None assessed (no quiz answers yet). Candidate topic to test later: who controls access when there is no admin (IdP dependency).
