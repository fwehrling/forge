---
name: forge-loop
description: >
  Autonomous iteration runner with cost caps, circuit breakers, and sandbox isolation.
  Use when: "run in a loop", "iterate autonomously", "AFK mode",
  "unattended iteration", "loop until done", "keep working overnight".
---

# /forge-loop — FORGE Autonomous Loop

This skill wraps `forge-loop.sh` to provide autonomous iteration with security guardrails.

## Usage

```bash
/forge-loop "Implement authentication module"
/forge-loop "Fix all failing tests" --mode afk --max-iterations 50
/forge-loop "Refactor database layer" --mode pair
```

## Options

| Option              | Default  | Description                                    |
| ------------------- | -------- | ---------------------------------------------- |
| `--max-iterations`  | 30       | Maximum iterations before stopping             |
| `--cost-cap`        | 10.00    | Cost cap in USD per loop                       |
| `--sandbox`         | docker   | Sandbox type: `docker` \| `local` \| `none`   |
| `--story`           | (none)   | Story file for context                         |
| `--mode`            | hitl     | Loop mode: `afk` \| `hitl` \| `pair`          |
| `--rate-limit`      | 60       | Max iterations per hour                        |
| `--monitor`         | false    | Enable live log tailing                        |
| `--fix-plan`        | (auto)   | Custom fix plan file path                      |

## Modes

| Mode     | Behavior             | HITL Gates                          | Usage              |
| -------- | -------------------- | ----------------------------------- | ------------------ |
| **afk**  | Fully autonomous     | None                                | Overnight, batch   |
| **hitl** | Semi-autonomous      | Confirmation every 5 iterations     | Default            |
| **pair** | Collaborative        | Continuous explanation, small commits| Active development |

## Security Guardrails

- **Cost cap**: Stops when estimated cost exceeds the configured limit
- **Circuit breakers**: Stops after consecutive errors, no progress, or repeated output
- **Rate limiting**: Max iterations per hour to prevent runaway loops
- **Sandbox**: Docker isolation with read-only mounts for sensitive files
- **Rollback**: Git tag checkpoints before each iteration (`forge-ckpt-iter-N`)

## Workflow

1. **Load context** (if FORGE project):
   - Read `.forge/memory/MEMORY.md` for project context (if exists)
   - Read the latest session from `.forge/memory/sessions/` for continuity
   - `forge-memory search "<task description>" --limit 3` (if available)

2. Validate arguments and check that a task description is provided
3. Locate the `forge-loop.sh` script at `~/.claude/skills/forge/forge-loop.sh`
4. Execute `forge-loop.sh` with the provided task and options:
   ```bash
   bash ~/.claude/skills/forge/forge-loop.sh "task description" [options]
   ```
5. Display the loop result (completed, blocked, cost_cap, circuit_breaker, etc.)
6. Show the log file location and state directory for inspection

7. **Save memory** (ensures iteration outcomes and blockers persist for future debugging context):
   ```bash
   forge-memory log "Loop terminée : {TASK}, résultat={RESULT}, {N} itérations" --agent loop
   forge-memory consolidate --verbose
   forge-memory sync
   ```

8. **Report to user**:

   ```
   FORGE Loop — Complete
   ──────────────────────
   Task       : <description>
   Result     : completed | blocked | cost_cap | circuit_breaker
   Iterations : N / max M
   Cost       : $X.XX / cap $Y.YY
   Duration   : Xm Ys

   Log: .forge/loop/<task-hash>/loop.log
   State: .forge/loop/<task-hash>/state/
   Checkpoints: forge-ckpt-iter-1 .. forge-ckpt-iter-N
   ```

## Checkpoint Management

```bash
# List available checkpoints
bash ~/.claude/skills/forge/forge-loop.sh checkpoint-list

# Restore a checkpoint
bash ~/.claude/skills/forge/forge-loop.sh rollback --story forge-ckpt-iter-5
```
