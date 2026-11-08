# Progress

2026-11-08: user paused the mentoring flow; full design drafted (design.md), admin role removed, stack fixed (Rails API, React, PostgreSQL), Docker dev setup done.
2026-11-08: implementation done in small commits (see `git log`): models, auth and roles, audit chain, employees, salary history/corrections,
exchange rates, reports, export, audit API, Excel/CSV import, React frontend. Backend: ~200 RSpec examples passing, RuboCop clean, Brakeman: no code issues.

2026-11-08: sign-in changed to username/password (user decision): User model, login with lockout, password change, session tokens, CLI account management; frontend updated. Backend now 239 RSpec examples.

Not done: operations items listed in design.md section 12; step 8 (final review, scale-it-10x, mock interview, failure-injection drill).

## Weak spots
None assessed (no quiz answers yet). Candidate topic to test later: who controls access when there is no admin (IdP dependency).
