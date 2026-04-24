---
name: forge-security-pro
description: >
  Deep security audit -- OWASP Top 10, hardening, React Native, Node.js, Stripe, Docker.
paths:
  - ".forge/**"
---

# FORGE Security Pro -- Deep Security Review

Standalone deep security review for prod-bound stacks. Pairs well with `forge-audit` when you want both a threat-modeled `docs/security.md` and a code-level review.

## Posture

Prioritize **real risk** over exhaustive checklist coverage. A finding is worth flagging if a realistic attacker could exploit it against this stack in this context. Don't pad reports with generic OWASP items that don't apply. Don't hedge on CRITICAL issues -- call them clearly -- but don't invent severity either.

## Approach

No fixed sequence. Work where the risk concentrates for the stack at hand:

- **Threat-model first**: what are the realistic attack vectors for this app? (auth bypass, IDOR, payment replay, data exfil, privilege escalation, etc.) This shapes what's worth auditing.
- **Trace sensitive flows end-to-end**: auth, payment, file upload, admin actions. For each, check: input validation, authN/authZ, state integrity, output encoding, logging.
- **Check the stack's typical failure modes**: OWASP Top 10 is a starting point, not a checklist. Adapt to what the code actually uses.

## Stack references

Only apply what's relevant to the actual stack in front of you:

- **Node / Express / Fastify** -- input validation, helmet config, CORS, rate limit on auth, JWT rotation + expiry, secrets hygiene.
- **React Native / Expo** -- no secrets in bundle, API key scoping, deep-link validation, webview sandbox, cert pinning where warranted.
- **Stripe webhooks** -- signature verification, idempotency keys, replay protection, event ordering.
- **Postgres / Supabase** -- parameterized queries, RLS policy coverage, least-priv DB roles.
- **Docker / nginx / TLS** -- non-root containers, modern TLS config, HSTS, rate limit at edge.
- **Auth** -- session management, refresh token rotation, brute-force protection, password hashing (Argon2/bcrypt with appropriate cost), MFA where warranted.

## Deliverable

Report findings grouped by severity, with **context** for each: the attack scenario, the realistic impact, and a concrete fix. Severity should reflect actual risk on this stack, not a generic OWASP level.

```
CRITICAL (fix before launch, blocks production)
  - [location] finding
    Attack: ...
    Impact: ...
    Fix: ...

HIGH (fix before production traffic)
  - ...

MEDIUM / RECOMMENDATIONS
  - ...
```

If a class of risk was checked and found clean, say so briefly -- that's informative too. Don't invent findings to fill categories.

## Compliance callouts

Flag compliance implications (GDPR, SOC2, HIPAA) when the audit surfaces them. Don't turn the security review into a legal audit -- defer detailed legal work to `forge-legal`.

## Limits

- Not a feature-dev skill. If a finding needs a refactor, describe it; the implementation is handled downstream.
- Not a UX skill. Security informs UX decisions, doesn't dictate them.
- CRITICAL findings are non-negotiable for launch. Everything else is a trade-off the user can accept with eyes open.

Flow progression is managed by the FORGE hub.
