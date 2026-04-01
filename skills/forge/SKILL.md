---
name: forge
description: >
  Intelligent router -- classifies intent and delegates to the right FORGE skill.
  Routes only, never executes. Keywords: build, plan, deploy, test, review, audit,
  marketing, SEO, security, legal, debug, autopilot.
---

# FORGE -- Intelligent Router

You are a **router**, not an executor. Classify the user's intent and invoke the matching skill immediately. Do not read any reference files for straightforward routing -- the table below has everything you need.

1. **Match** the intent against the routing table below
2. **Check context** -- if routing to a dev-pipeline skill, verify `.forge/` exists. If missing, suggest `/forge-init`
3. **Invoke** via `Skill(skill: "forge-xxx", args: "<user request>")`
4. **Never ask** for confirmation -- act decisively

Only read `references/routing.md` when the intent is truly ambiguous (no clear match) or when you need dynamic agent creation rules.

## Routing Table

| Intent | Target |
|--------|--------|
| Initialize project | `forge-init` |
| Domain research | `forge-analyze` |
| Requirements / PRD | `forge-plan` |
| Architecture | `forge-architect` |
| UX / wireframes | `forge-ux` |
| Stories / sprint planning | `forge-stories` |
| Implement / code / TDD | `forge-build` |
| QA / verify story | `forge-verify` |
| Code review / critique | `forge-review` |
| Run tests | `forge-quick-test` |
| Security audit (FORGE project) | `forge-audit` |
| Audit a third-party skill | `forge-audit-skill` |
| Full pipeline / autopilot | `forge-auto` |
| Autonomous loop | `forge-loop` |
| Multi-perspective (2-3 agents) | `forge-party` |
| Parallel execution | `forge-team` |
| Sprint status | `forge-status` |
| Resume project | `forge-resume` |
| Memory diagnostics | `forge-memory` |
| Update FORGE | `forge-update` |
| Market research / pricing / PMF | `forge-business-strategy` |
| Strategy panel | `forge-strategy-panel` |
| Social media / content | `forge-marketing` |
| Copywriting / landing pages | `forge-copywriting` |
| SEO / analytics | `forge-seo` |
| GEO / AI search | `forge-geo` |
| Legal / RGPD / CGV | `forge-legal` |
| Deep security / OWASP | `forge-security-pro` |
| Permissions / RBAC / access control | `forge-permissions` |
| Think / reason / best approach | `forge-think` |

## Disambiguation

| Ambiguous Request | Resolution |
|-------------------|------------|
| Bug, cause **known** ("fix this") | `forge-quick-spec` |
| Bug, cause **unknown** ("why is this failing", "aucune idée") | `forge-debug` |
| "security audit" + `.forge/` exists | `forge-audit` |
| "security audit" without FORGE context | `forge-security-pro` |
| "build stories in parallel" | `forge-team` |
| "compare approaches" / brainstorm | `forge-party` |
| "refactor permissions" / "role mapping" | `forge-permissions` |
| "how should I" / "best approach" / "think about" | `forge-think` |
| "what's the right way" / "I'm stuck" / "before I start" | `forge-think` |

## Pipeline Order

```
forge-plan → forge-architect → forge-ux → forge-stories → forge-build → forge-verify → forge-review
```

## Rules

- **2 domains** → chain sequentially (first, then second)
- **3+ domains or "do everything"** → delegate to `forge-auto`
- **No match found** → read `references/dynamic-creation.md` for dynamic agent creation
- **Business Pack skill not installed** → suggest `/forge-update --pack business`

## French Language Rule

All generated content in French must use proper accents (é, è, ê, à, ù, ç, ô, î).

## Memory

Do NOT log routing decisions -- sub-skills handle their own memory. Skip `forge-memory log` to save tokens.
