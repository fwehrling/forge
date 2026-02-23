# FORGE — Project Guidelines

## About This Repository

This is the FORGE framework source repository. Skills are in `skills/` and get installed to `~/.claude/skills/` by users.

## Structure

```
skills/
  forge/              # Core framework (SKILL.md + scripts + docs)
  forge-auto/         # Autopilot mode
  forge-team/         # Agent Teams integration (parallel execution)
  forge-build/        # Dev agent
  forge-verify/       # QA agent
  forge-*/            # Other agent skills
```

## Conventions

- **SKILL.md files** use YAML frontmatter (`name`, `description`) followed by Markdown instructions
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
5. **Team Size**: Max 4 Dev + 1 QA teammates. Each Dev handles exactly 1 story.
6. **Cleanup**: The lead is responsible for cleanup of temp files and memory consolidation at the end of team execution.
