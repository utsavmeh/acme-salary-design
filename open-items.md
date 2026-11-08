# Open items

Closed by draft decisions (see decisions.md): reporting questions list, rate setter, rate corrections, multi-year rates, frequency, report currency, admin removal.

Still need user confirmation:
1. CRITICAL: does ACME have a sign-in system (IdP) with MFA and groups? Today the app verifies a shared-secret token; the IdP connection is not built.
2. Country scoping for HR users (assumed: none)
3. Department/title available in the Excel files (import requires them)
4. Retention period and per-country data-residency rules (needs Legal)
5. Upgrade plan: Ruby 3.2 and Rails 8.0 are end-of-life (Brakeman notice)
6. Operations before go-live: backups/restore drill, deployment, monitoring, rate limiting, field-level encryption
