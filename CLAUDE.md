# FORGE — Project Guidelines

## About This Repository

This is the FORGE framework source repository. Skills are in `skills/` and get installed to `~/.claude/skills/` by users.

## Structure

```
skills/
  forge/              # Core framework — Intelligent Router (SKILL.md + scripts + docs)
  forge-auto/         # Autopilot mode
  forge-build/        # Dev agent
  forge-debug/        # Systematic root cause investigation
  forge-team/         # Agent Teams integration (parallel execution)
  forge-verify/       # QA agent
  forge-*/            # Other core skills
packs/
  business/           # Optional Business Pack (installed via /forge-update --pack business)
    forge-marketing/  # Social media & content strategy
    forge-copywriting/# Copywriting & conversion
    forge-seo/        # SEO & analytics
    forge-geo/        # GEO/LLMO & AI search
    forge-legal/      # E-commerce & auto-entrepreneur law
    forge-security-pro/# Deep security audit & OWASP
    forge-business-strategy/ # Market research & business strategy
    forge-strategy-panel/    # Multi-expert strategy panel
packs.yaml            # Pack manifest (core vs business skill lists)
```

## Conventions

- **SKILL.md files** use YAML frontmatter (`name`, `description`) followed by Markdown instructions
- **Descriptions** must be ultra-concise (~120 chars max): key capability + artifact produced. No "Use when:" lists — keep trigger keywords natural in the text. Every char costs tokens on every conversation turn
- **Context Cache**: Skills must check if files (docs/prd.md, docs/architecture.md, MEMORY.md) were already loaded in the conversation before re-reading. Add "skip if already loaded" directives in workflow steps
- **French Language Rule** lives only in the hub skill (`forge/SKILL.md`), not in satellite skills — language is a user-level preference configured in `~/.claude/CLAUDE.md`
- **Output templates**: Every agent skill should include a concrete ASCII report template showing the expected output format
- **Memory save blocks**: Explain WHY memory matters (e.g., "ensures QA verdicts persist for trend analysis") instead of just "MANDATORY — never skip"
- **Step numbering**: Always use sequential integers (1, 2, 3...) — never 1.5, 2.5, 5b, 5c
- **Agent personas** are referenced via `references/agents/*.md` (created by `/forge-init` in user projects, not stored here)
- **Artifacts** follow the pipeline: `docs/prd.md` -> `docs/architecture.md` -> `docs/stories/*.md` -> `src/` + `tests/`
- **Sprint tracking** via `.forge/sprint-status.yaml` in user projects

## FORGE + Agent Teams Integration

### Decision Table

| Situation | Command | Mechanism |
|---|---|---|
| Full pipeline with parallel stories | `/forge-team pipeline "objective"` | Agent Teams (real processes) |
| Multi-perspective analysis with debate | `/forge-team party "topic"` | Agent Teams (real processes) |
| Parallel build of existing stories | `/forge-team build STORY-001 STORY-002` | Agent Teams (real processes) |
| Sequential pipeline (1 story at a time) | `/forge-auto` | Single process |
| Quick 2-3 agent analysis | `/forge-party "topic"` | Subagents (Task tool) |
| Single story implementation | `/forge-build STORY-XXX` | Single process |

### Coordination Rules for Teammates

When running as a teammate in an Agent Teams session:

1. **File Ownership**: Each teammate writes ONLY to its assigned directories. Check your spawn prompt for your file scope. Never write outside your scope.
2. **Memory Protocol**: Read `.forge/memory/MEMORY.md` at start (read-only). Do NOT write to session logs — the lead handles memory consolidation.
3. **Sprint Status**: Only update `.forge/sprint-status.yaml` for your own assigned story. The lead performs final consolidation.
4. **Task List**: Use the shared task list to communicate progress and results. Mark tasks as complete only after passing all validation gates.
5. **Team Size**: Max 4 Dev + 1 QA + 1 Reviewer teammates. Each Dev handles exactly 1 story.
6. **Cleanup**: The lead is responsible for cleanup of temp files and memory consolidation at the end of team execution.
