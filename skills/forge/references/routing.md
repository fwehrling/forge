# FORGE Routing Reference

## Intent Classification

Analyze requests along 4 dimensions:

### Domain

| Domain | Signals |
|--------|---------|
| `dev-pipeline` | Build, implement, code, test, deploy, plan, architect, stories, verify, review, UX, analyze |
| `dev-tooling` | Status, resume, memory, update, initialize, loop |
| `business` | Strategy, competition, market analysis, business model, pricing, positioning |
| `marketing` | Social media, LinkedIn, content, copywriting, landing page, email funnel |
| `seo` | SEO, keywords, analytics, Core Web Vitals, GEO, AI search, LLMO |
| `permissions` | Permissions, RBAC, ACL, authorization, roles, access control, droits |
| `reasoning` | Think, reason, approach, best way, how should I, design decision, stuck |
| `security` | OWASP, vulnerabilities, threat model, hardening |
| `legal` | RGPD, CGV, mentions legales, auto-entrepreneur, e-commerce |
| `specialist` | Framework-specific (Angular, Next.js, etc.) -- dynamic agent creation |
| `unknown` | Cannot classify -- ask one clarifying question |

### Action
`analyze`, `plan`, `design`, `build`, `test`, `review`, `deploy`, `audit`, `fix`, `write`, `optimize`, `create`, `check`, `resume`, `status`

### Specificity
- `direct`: User names a specific skill -> route to it
- `targeted`: One clear match -> route to it
- `broad`: Multiple matches -> pick best or chain if exactly 2
- `novel`: No match -> dynamic creation

### Scale
- `quick`: Bug fix, single question -> one target
- `standard`: Feature, module -> single skill
- `full`: Complete pipeline -> `/forge auto`
- `parallel`: Multiple independent tasks -> `/forge team`

## Full Routing Table

### Dev Pipeline

| Intent | Target |
|--------|--------|
| Initialize project | `forge-init` |
| Domain research, requirements | `forge-analyze` |
| Product requirements, PRD | `forge-plan` |
| Architecture, tech stack | `forge-architect` |
| UX design, wireframes | `forge-ux` |
| Story decomposition | `forge-stories` |
| Implement code, TDD | `forge-build` |
| QA, certification | `forge-verify` |
| Bug investigation (cause unknown) | `forge-debug` |
| Quick bug fix (cause known) | `forge-quick-spec` |
| Run existing tests | `forge-quick-test` |
| Code review, critique | `forge-review` |
| Security audit (FORGE project) | `forge-audit` |
| Audit third-party skill | `forge-audit-skill` |
| Permissions, RBAC, access control | `forge-permissions` |
| Deep reasoning, best approach, design decision | `forge-think` |
| Full pipeline, autopilot | `forge-auto` |
| Autonomous loop | `forge-loop` |
| Multi-perspective (2-3 agents) | `forge-party` |
| Parallel execution | `forge-team` |

### Dev Tooling

| Intent | Target |
|--------|--------|
| Sprint status | `forge-status` |
| Resume project | `forge-resume` |
| Memory diagnostics | `forge-memory` |
| Update FORGE | `forge-update` |

### Business Pack

| Intent | Target |
|--------|--------|
| Market research, TAM/SAM/SOM, pricing, PMF | `forge-business-strategy` |
| Multi-expert strategy panel | `forge-strategy-panel` |
| Social media, content calendar | `forge-marketing` |
| Copywriting, landing pages, email funnels | `forge-copywriting` |
| Technical SEO, Core Web Vitals, keywords | `forge-seo` |
| GEO/LLMO, AI search visibility | `forge-geo` |
| E-commerce law, RGPD, CGV | `forge-legal` |
| Deep security audit, OWASP | `forge-security-pro` |

## Disambiguation

| Ambiguous Request | Resolution |
|-------------------|------------|
| "security audit" + `.forge/` exists | `forge-audit` |
| "security audit" without FORGE context | `forge-security-pro` |
| "fais tout" / scope unclear | `forge-auto` |
| Chain > 2 steps | `forge-auto` |
| "fix this bug" (cause known) | `forge-quick-spec` |
| "why is this failing" (cause unknown) | `forge-debug` |
| "run the tests" | `forge-quick-test` |
| "build stories in parallel" | `forge-team` |
| "compare approaches" | `forge-party` |
| "refactor permissions" / "role-based access" | `forge-permissions` |
| "how should I" / "best approach" / "think about" | `forge-think` |
| "what's the right way" / "I'm stuck on design" | `forge-think` |
| Specialist/framework question | Dynamic agent creation |

## Chaining Rules

- Exactly 2 domains -> chain sequentially (first target, then second)
- 3+ domains -> delegate to `/forge auto`
- "do everything" or unclear scope -> `/forge auto`
