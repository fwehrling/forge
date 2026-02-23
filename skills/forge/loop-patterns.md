# Autonomous Loop Patterns for FORGE

## Core Concept

Autonomous loops are iteration cycles where Claude Code repeatedly works on
a task until completion criteria are met. FORGE wraps these loops with security
guardrails and structured task management.

## Pattern 1: Single Task Loop

```bash
/forge-loop "Implement user registration endpoint" \
  --max-iterations 20 \
  --story docs/stories/story-001.md
```

How it works:

1. FORGE generates PROMPT.md from story file
2. Claude receives prompt + filesystem state
3. Implements incrementally, committing after each change
4. Stop hook intercepts exit attempts
5. Same prompt re-fed — Claude sees its previous commits
6. Loop exits when: tests pass + EXIT_SIGNAL emitted

## Pattern 2: Phased Development

```bash
# Phase 1: Data models
/forge-loop "Phase 1: Create data models and migrations" \
  --max-iterations 15 \
  --completion-promise "PHASE1_DONE"

# Phase 2: API layer (depends on Phase 1)
/forge-loop "Phase 2: Build REST API endpoints" \
  --max-iterations 25 \
  --completion-promise "PHASE2_DONE"

# Phase 3: Frontend
/forge-loop "Phase 3: Build UI components" \
  --max-iterations 30 \
  --completion-promise "PHASE3_DONE"
```

## Pattern 3: Parallel Feature Development

```bash
# Create isolated worktrees
git worktree add ../project-auth -b feature/auth
git worktree add ../project-api -b feature/api

# Terminal 1: Auth feature
cd ../project-auth
/forge-loop "Implement authentication" --max-iterations 20

# Terminal 2: API feature (simultaneously)
cd ../project-api
/forge-loop "Build REST API" --max-iterations 25
```

## Pattern 4: Overnight Batch

```bash
#!/bin/bash
# overnight-forge.sh — Run before bed

export FORGE_COST_CAP=20.00  # Total budget for tonight

# Project 1: Tests
cd /path/to/project1
forge-loop "Add unit tests to all services" --max-iterations 50 --sandbox docker

# Project 2: Documentation
cd /path/to/project2
forge-loop "Generate JSDoc for all public functions" --max-iterations 30 --sandbox docker

# Project 3: Migration
cd /path/to/project3
forge-loop "Migrate callbacks to async/await" --max-iterations 40 --sandbox docker
```

## Prompt Engineering for Autonomous Loops

### Good Prompts (specific, measurable, verifiable)

```
"Add input validation to all API endpoints using Zod schemas.
    Each endpoint must validate request body, query params, and path params.
    Tests must cover valid input, missing required fields, and invalid types."

"Convert all React class components in src/components/ to functional
    components using hooks. Preserve all existing behavior. All existing
    tests must pass without modification."
```

### Bad Prompts (vague, unmeasurable)

```
"Improve the codebase"
"Make it more secure"
"Refactor for better performance"
```

### Prompt Template

```markdown
## Task

[Specific, actionable description]

## Scope

- Files: [Which files/directories to modify]
- Exclusions: [What NOT to touch]

## Completion Criteria

- [ ] [Specific, testable criterion 1]
- [ ] [Specific, testable criterion 2]
- [ ] All tests pass: `pnpm test`
- [ ] No lint errors: `pnpm lint`

## Context

- Architecture: See docs/architecture.md section [X]
- Story: See docs/stories/story-[N].md
- Patterns: Follow existing code in src/[module]/

## If Stuck

After 3 failed attempts on the same issue:

1. Document the blocker in BLOCKERS.md
2. Skip to next criterion if possible
3. Output "FORGE_BLOCKED: [description]" to exit
```

## Exit Detection

FORGE uses dual-condition exit gates:

```
Exit requires BOTH:
1. Completion indicators detected in output (tests pass, criteria met)
2. Explicit EXIT_SIGNAL from Claude ("FORGE_COMPLETE: ...")

This prevents premature exit when Claude *thinks* it's done but tests
are still failing.
```

## Pattern 5: Task-Tracked Loop (fix_plan.md)

```bash
# Loop with explicit task tracking via fix_plan.md
/forge-loop "Fix all failing tests in auth module" \
  --fix-plan docs/fix-plan-auth.md \
  --mode hitl
```

How it works:

1. FORGE creates/loads a `fix_plan.md` file with task checklist
2. Each iteration, Claude reads the fix plan to know what's done/remaining
3. Claude updates the fix plan: marks completed steps `[x]`, adds new steps
4. The fix plan provides continuity between iterations (context that survives)
5. On completion, fix plan shows full history of what was done

Fix Plan structure:

```markdown
# Fix Plan — FORGE Loop

## Task

[Auto-populated from --task]

## Steps

- [x] Analyze failing tests → 3 tests failing in auth.test.ts
- [x] Fix test 1: missing mock for UserService
- [ ] Fix test 2: incorrect assertion on token expiry
- [ ] Fix test 3: race condition in session refresh
- [ ] Run full test suite to verify no regressions

## Blockers

(none)

## Notes

- Iteration 1: identified 3 failing tests
- Iteration 2: fixed UserService mock pattern
```

Benefits:

- Provides persistent context across iterations
- Claude can see what it already tried (avoids loops)
- Human can read the plan during HITL mode
- Useful for post-mortem analysis

## Pattern 6: Monitored Loop

```bash
# Loop with live monitoring (tail -f log)
/forge-loop "Implement search feature" \
  --monitor \
  --mode hitl
```

The `--monitor` flag starts a `tail -f` on the log file, giving real-time
visibility into loop progress. Combined with HITL mode, the human can
observe progress and intervene every 5 iterations.

## Pattern 7: Rate-Limited Overnight Batch

```bash
# Overnight with strict rate limiting and AFK mode
/forge-loop "Add comprehensive tests" \
  --mode afk \
  --max-iterations 100 \
  --cost-cap 25.00 \
  --rate-limit 30 \
  --sandbox docker
```

Rate limiting at 30 iterations/hour means:

- Max 2 minutes between iterations
- Prevents API abuse during long unattended runs
- Combined with cost cap for double protection

## Cost Management

| Model         | Approx. Cost per Iteration | 20 Iterations |
| ------------- | -------------------------- | ------------- |
| Claude Sonnet | ~$0.10-0.30                | $2-6          |
| Claude Opus   | ~$0.30-1.00                | $6-20         |
| Claude Haiku  | ~$0.02-0.05                | $0.40-1       |

Recommendations:

- Use Sonnet for most loops (best cost/quality)
- Use Haiku for simple, repetitive tasks (docs, types)
- Use Opus only for complex architecture decisions
- Set cost caps in `.forge/config.yml`
- Monitor with `/forge-status --costs`
