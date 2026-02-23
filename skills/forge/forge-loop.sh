#!/bin/bash
# FORGE Secured Autonomous Loop Runner
# Usage: forge-loop.sh "task description" [options]
#
# Options:
#   --max-iterations N    Maximum iterations (default: 30)
#   --cost-cap N          Cost cap in USD (default: 10.00)
#   --sandbox TYPE        Sandbox type: docker|local|none (default: docker)
#   --story PATH          Story file for context
#   --completion TEXT      Completion promise string
#   --monitor             Enable live monitoring (tail -f log)
#   --mode MODE           Loop mode: afk|hitl|pair (default: hitl)
#   --rate-limit N        Max iterations per hour (default: 60)
#   --fix-plan PATH       Fix plan file for task tracking

set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────
TASK=""
MAX_ITERATIONS=30
COST_CAP=10.00
SANDBOX="docker"
STORY=""
COMPLETION_PROMISE="FORGE_COMPLETE"
MONITOR=false
MODE="hitl"
RATE_LIMIT=60
FIX_PLAN=""
ITERATION=0
TOTAL_COST=0.00
CONSECUTIVE_ERRORS=0
MAX_CONSECUTIVE_ERRORS=3
NO_PROGRESS_COUNT=0
MAX_NO_PROGRESS=5
LAST_OUTPUT_HASH=""
SAME_OUTPUT_COUNT=0
MAX_SAME_OUTPUT=3
SANDBOX_IMAGE="${FORGE_SANDBOX_IMAGE:-}"
STATE_DIR=".forge-state"
LOG_FILE=".forge/loop-$(date +%s).log"
OUTPUT_FILE=".forge/loop-output.txt"
MAX_CHECKPOINTS=5

# ─── Parse Arguments ─────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --max-iterations) MAX_ITERATIONS="$2"; shift 2 ;;
    --cost-cap) COST_CAP="$2"; shift 2 ;;
    --sandbox) SANDBOX="$2"; shift 2 ;;
    --story) STORY="$2"; shift 2 ;;
    --completion) COMPLETION_PROMISE="$2"; shift 2 ;;
    --monitor) MONITOR=true; shift ;;
    --mode) MODE="$2"; shift 2 ;;
    --rate-limit) RATE_LIMIT="$2"; shift 2 ;;
    --fix-plan) FIX_PLAN="$2"; shift 2 ;;
    *) TASK="$1"; shift ;;
  esac
done

if [ -z "$TASK" ]; then
  echo "Error: Task description required"
  echo "Usage: forge-loop.sh \"task description\" [options]"
  exit 1
fi

# Validate mode
case "$MODE" in
  afk|hitl|pair) ;;
  *) echo "Error: Invalid mode '$MODE'. Use: afk|hitl|pair"; exit 1 ;;
esac

# ─── State Directory ─────────────────────────────────────────────
mkdir -p "$STATE_DIR"
mkdir -p .forge

STATE_FILE="${STATE_DIR}/state.json"
HISTORY_FILE="${STATE_DIR}/history.jsonl"

init_state() {
  cat > "$STATE_FILE" << EOF
{
  "task": $(printf '%s' "$TASK" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))' 2>/dev/null || echo "\"$TASK\""),
  "mode": "$MODE",
  "status": "running",
  "iteration": 0,
  "max_iterations": $MAX_ITERATIONS,
  "cost_cap": $COST_CAP,
  "sandbox": "$SANDBOX",
  "consecutive_errors": 0,
  "no_progress_count": 0,
  "same_output_count": 0,
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "last_checkpoint": null,
  "checkpoints": []
}
EOF
}

update_state() {
  local key="$1"
  local value="$2"
  if command -v python3 &>/dev/null; then
    python3 -c "
import json, sys
with open('$STATE_FILE', 'r') as f:
    state = json.load(f)
state['$key'] = $value
with open('$STATE_FILE', 'w') as f:
    json.dump(state, f, indent=2)
" 2>/dev/null || true
  fi
}

append_history() {
  local event="$1"
  local detail="$2"
  echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"iteration\":$ITERATION,\"event\":\"$event\",\"detail\":$(printf '%s' "$detail" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))' 2>/dev/null || echo "\"$detail\"")}" >> "$HISTORY_FILE"
}

init_state

# ─── Logging ─────────────────────────────────────────────────────
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# ─── Monitor Mode ────────────────────────────────────────────────
MONITOR_PID=""
if [ "$MONITOR" = true ]; then
  log "Monitor enabled: tailing $LOG_FILE"
  tail -f "$LOG_FILE" &
  MONITOR_PID=$!
fi

cleanup_monitor() {
  if [ -n "$MONITOR_PID" ] && kill -0 "$MONITOR_PID" 2>/dev/null; then
    kill "$MONITOR_PID" 2>/dev/null || true
  fi
}
trap cleanup_monitor EXIT

# ─── Fix Plan ────────────────────────────────────────────────────
init_fix_plan() {
  if [ -z "$FIX_PLAN" ]; then
    FIX_PLAN="${STATE_DIR}/fix_plan.md"
  fi
  if [ ! -f "$FIX_PLAN" ]; then
    cat > "$FIX_PLAN" << EOF
# Fix Plan — FORGE Loop

## Task
${TASK}

## Steps
<!-- Updated by each iteration. Mark completed steps with [x] -->
- [ ] Analyze current state and identify required changes
- [ ] Implement changes
- [ ] Write/update tests
- [ ] Verify all tests pass
- [ ] Clean up and commit

## Blockers
<!-- Document any blockers encountered -->
(none)

## Notes
<!-- Iteration notes appended automatically -->
EOF
    log "Fix plan created: $FIX_PLAN"
  fi
}

init_fix_plan

# ─── Generate PROMPT.md ─────────────────────────────────────────
generate_prompt() {
  local story_context=""
  if [ -n "$STORY" ] && [ -f "$STORY" ]; then
    story_context="## Story Context
Read the story file at \`${STORY}\` for full context, acceptance criteria,
and implementation guidance."
  fi

  local fix_plan_context=""
  if [ -f "$FIX_PLAN" ]; then
    fix_plan_context="## Fix Plan
Read \`${FIX_PLAN}\` for the current task tracking. Update completed steps with [x].
Add new steps if you discover additional work needed."
  fi

  local mode_instructions=""
  case "$MODE" in
    afk)
      mode_instructions="## Mode: AFK (Autonomous)
You are running fully autonomously. Make decisions without human input.
If truly blocked after 3 attempts, output FORGE_BLOCKED."
      ;;
    hitl)
      mode_instructions="## Mode: HITL (Human-in-the-Loop)
A human may be monitoring. For destructive or ambiguous decisions,
document your reasoning clearly. Prefer safe, reversible choices."
      ;;
    pair)
      mode_instructions="## Mode: Pair Programming
Work collaboratively. Explain your reasoning as you go.
Commit smaller, more frequent changes for easier review."
      ;;
  esac

  cat > PROMPT.md << PROMPT_EOF
# FORGE Loop — Iteration ${ITERATION}/${MAX_ITERATIONS}

## Task
${TASK}

${story_context}

${fix_plan_context}

${mode_instructions}

## Completion Criteria
When ALL of the following are true, output "${COMPLETION_PROMISE}":
- All acceptance criteria from the task/story are met
- All tests pass
- No linting or type errors
- Code committed with conventional commit message

## Working State
- Check git log for previous iteration work
- Run tests to see current state
- Read docs/architecture.md for constraints

## Rules
- Commit after each meaningful change
- Do NOT modify files outside declared scope
- Do NOT install dependencies without documenting why
- Do NOT hardcode secrets or credentials
- If stuck after 3 attempts: document in BLOCKERS.md and output "FORGE_BLOCKED"

## Progress
- Iteration: ${ITERATION}/${MAX_ITERATIONS}
- Consecutive errors: ${CONSECUTIVE_ERRORS}/${MAX_CONSECUTIVE_ERRORS}
- No-progress count: ${NO_PROGRESS_COUNT}/${MAX_NO_PROGRESS}
- Mode: ${MODE}
PROMPT_EOF
}

# ─── Git Checkpoint (via tags) ───────────────────────────────────
checkpoint() {
  if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    git add -A 2>/dev/null || true
    # Commit staged changes if any
    if ! git diff --cached --quiet 2>/dev/null; then
      git commit -m "forge: checkpoint iter-${ITERATION}" --no-verify 2>/dev/null || true
    fi
    # Create a lightweight tag for this checkpoint
    local tag_name="forge-ckpt-iter-${ITERATION}"
    git tag -f "$tag_name" 2>/dev/null || true
    log "Checkpoint: tag $tag_name created"
    update_state "last_checkpoint" "\"$tag_name\""
    append_history "checkpoint" "$tag_name"

    # Prune old checkpoints beyond MAX_CHECKPOINTS
    local tags
    tags=$(git tag -l 'forge-ckpt-iter-*' --sort=-version:refname 2>/dev/null || true)
    local count=0
    while IFS= read -r t; do
      [ -z "$t" ] && continue
      count=$((count + 1))
      if [ "$count" -gt "$MAX_CHECKPOINTS" ]; then
        git tag -d "$t" 2>/dev/null || true
        log "Pruned old checkpoint: $t"
      fi
    done <<< "$tags"
  fi
}

# ─── Rollback Commands ───────────────────────────────────────────
rollback_list() {
  echo "Available checkpoints:"
  git tag -l 'forge-ckpt-iter-*' --sort=-version:refname 2>/dev/null || echo "(none)"
}

rollback_restore() {
  local target="${1:-}"
  if [ -z "$target" ]; then
    echo "Usage: forge-loop.sh rollback <tag-name>"
    echo ""
    rollback_list
    return 1
  fi
  if git rev-parse "$target" > /dev/null 2>&1; then
    log "Restoring to checkpoint: $target"
    git reset --hard "$target" 2>/dev/null
    append_history "rollback" "$target"
    log "Restored to $target"
  else
    echo "Error: Checkpoint '$target' not found"
    rollback_list
    return 1
  fi
}

# Handle rollback subcommands
if [ "$TASK" = "rollback" ] || [ "$TASK" = "checkpoint-list" ]; then
  case "$TASK" in
    rollback)
      rollback_restore "${STORY:-}"  # reuse STORY arg as target
      ;;
    checkpoint-list)
      rollback_list
      ;;
  esac
  exit 0
fi

# ─── Safety Checks ───────────────────────────────────────────────
check_cost_cap() {
  local estimated_cost
  estimated_cost=$(echo "$ITERATION * 0.20" | bc -l 2>/dev/null || echo "0")
  if (( $(echo "$estimated_cost > $COST_CAP" | bc -l 2>/dev/null || echo 0) )); then
    log "Cost cap reached (~\$${estimated_cost} > \$${COST_CAP}). Stopping."
    update_state "status" "\"cost_cap_reached\""
    append_history "circuit_breaker" "cost_cap"
    return 1
  fi
  return 0
}

# Circuit Breaker 1: Consecutive errors
check_consecutive_errors() {
  if [ "$CONSECUTIVE_ERRORS" -ge "$MAX_CONSECUTIVE_ERRORS" ]; then
    log "Circuit breaker: ${CONSECUTIVE_ERRORS} consecutive errors"
    update_state "status" "\"circuit_breaker_errors\""
    append_history "circuit_breaker" "consecutive_errors=$CONSECUTIVE_ERRORS"
    return 1
  fi
  return 0
}

# Circuit Breaker 2: No progress (output doesn't change meaningfully)
check_no_progress() {
  if [ "$NO_PROGRESS_COUNT" -ge "$MAX_NO_PROGRESS" ]; then
    log "Circuit breaker: no progress for ${NO_PROGRESS_COUNT} iterations"
    update_state "status" "\"circuit_breaker_no_progress\""
    append_history "circuit_breaker" "no_progress=$NO_PROGRESS_COUNT"
    return 1
  fi
  return 0
}

# Circuit Breaker 3: Same output repeated (stuck in loop)
check_same_output() {
  if [ "$SAME_OUTPUT_COUNT" -ge "$MAX_SAME_OUTPUT" ]; then
    log "Circuit breaker: same output repeated ${SAME_OUTPUT_COUNT} times"
    update_state "status" "\"circuit_breaker_same_output\""
    append_history "circuit_breaker" "same_output=$SAME_OUTPUT_COUNT"
    return 1
  fi
  return 0
}

# ─── Rate Limiting ───────────────────────────────────────────────
ITERATION_START_TIMES=()

rate_limit_wait() {
  if [ "$RATE_LIMIT" -le 0 ]; then
    return
  fi
  local now
  now=$(date +%s)
  # Remove entries older than 1 hour
  local new_times=()
  for t in "${ITERATION_START_TIMES[@]+"${ITERATION_START_TIMES[@]}"}"; do
    if [ $((now - t)) -lt 3600 ]; then
      new_times+=("$t")
    fi
  done
  ITERATION_START_TIMES=("${new_times[@]+"${new_times[@]}"}")

  # If at rate limit, wait
  if [ "${#ITERATION_START_TIMES[@]}" -ge "$RATE_LIMIT" ]; then
    local oldest="${ITERATION_START_TIMES[0]}"
    local wait_seconds=$((3600 - (now - oldest) + 1))
    if [ "$wait_seconds" -gt 0 ]; then
      log "Rate limit: waiting ${wait_seconds}s (${RATE_LIMIT}/hour)"
      sleep "$wait_seconds"
    fi
  fi
  ITERATION_START_TIMES+=("$(date +%s)")
}

# ─── HITL Confirmation ───────────────────────────────────────────
hitl_confirm() {
  local message="$1"
  if [ "$MODE" = "hitl" ] || [ "$MODE" = "pair" ]; then
    echo ""
    echo "=== HITL Gate ==="
    echo "$message"
    echo -n "Continue? [Y/n/q(uit)]: "
    read -r response < /dev/tty 2>/dev/null || response="y"
    case "$response" in
      n|N) return 1 ;;
      q|Q) log "User quit via HITL gate"; exit 0 ;;
      *) return 0 ;;
    esac
  fi
  return 0
}

# ─── Sandbox Wrapper ─────────────────────────────────────────────
run_in_sandbox() {
  local cmd="$1"

  # Resolve Docker image: env var > .forge/config.yml > default
  if [ -z "$SANDBOX_IMAGE" ] && [ -f ".forge/config.yml" ]; then
    SANDBOX_IMAGE=$(python3 -c "
import yaml
try:
    with open('.forge/config.yml') as f:
        cfg = yaml.safe_load(f)
    print(cfg.get('loop',{}).get('sandbox',{}).get('image',''))
except: pass
" 2>/dev/null || echo "")
  fi
  SANDBOX_IMAGE="${SANDBOX_IMAGE:-node:22-alpine}"

  case "$SANDBOX" in
    docker)
      docker run --rm \
        -v "$(pwd)/src:/workspace/src:rw" \
        -v "$(pwd)/tests:/workspace/tests:rw" \
        -v "$(pwd)/docs:/workspace/docs:ro" \
        -v "$(pwd)/PROMPT.md:/workspace/PROMPT.md:ro" \
        --network none \
        --memory 2g \
        --cpus 2 \
        "$SANDBOX_IMAGE" \
        sh -c "$cmd"
      ;;
    local)
      eval "$cmd"
      ;;
    none)
      log "Running WITHOUT sandbox"
      eval "$cmd"
      ;;
  esac
}

# ─── Output Analysis ─────────────────────────────────────────────
analyze_output() {
  if [ ! -f "$OUTPUT_FILE" ]; then
    NO_PROGRESS_COUNT=$((NO_PROGRESS_COUNT + 1))
    update_state "no_progress_count" "$NO_PROGRESS_COUNT"
    return
  fi

  # Check for completion
  if grep -q "$COMPLETION_PROMISE" "$OUTPUT_FILE"; then
    log "Completion signal detected: ${COMPLETION_PROMISE}"
    log "FORGE Loop completed in ${ITERATION} iterations"
    update_state "status" "\"completed\""
    append_history "completed" "iter=$ITERATION"
    LOOP_RESULT="completed"
    return
  fi

  # Check for blocked
  if grep -q "FORGE_BLOCKED" "$OUTPUT_FILE"; then
    log "Task blocked. See BLOCKERS.md for details."
    update_state "status" "\"blocked\""
    append_history "blocked" "iter=$ITERATION"
    LOOP_RESULT="blocked"
    return
  fi

  # Check for errors (Circuit Breaker 1)
  if grep -q "ERROR\|FAILED\|EXCEPTION" "$OUTPUT_FILE"; then
    CONSECUTIVE_ERRORS=$((CONSECUTIVE_ERRORS + 1))
    log "Error detected (${CONSECUTIVE_ERRORS}/${MAX_CONSECUTIVE_ERRORS})"
    update_state "consecutive_errors" "$CONSECUTIVE_ERRORS"
    append_history "error" "consecutive=$CONSECUTIVE_ERRORS"
  else
    CONSECUTIVE_ERRORS=0
    update_state "consecutive_errors" "0"
  fi

  # Check for same output (Circuit Breaker 3)
  local current_hash
  current_hash=$(md5sum "$OUTPUT_FILE" 2>/dev/null | cut -d' ' -f1 || md5 -q "$OUTPUT_FILE" 2>/dev/null || echo "unknown")
  if [ "$current_hash" = "$LAST_OUTPUT_HASH" ]; then
    SAME_OUTPUT_COUNT=$((SAME_OUTPUT_COUNT + 1))
    log "Same output detected (${SAME_OUTPUT_COUNT}/${MAX_SAME_OUTPUT})"
    update_state "same_output_count" "$SAME_OUTPUT_COUNT"
  else
    SAME_OUTPUT_COUNT=0
    update_state "same_output_count" "0"
  fi
  LAST_OUTPUT_HASH="$current_hash"

  # Check for progress (Circuit Breaker 2): compare git diff
  if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    local changes
    changes=$(git diff --stat HEAD~1 2>/dev/null | tail -1 || echo "")
    if [ -z "$changes" ] || echo "$changes" | grep -q "0 insertions.*0 deletions"; then
      NO_PROGRESS_COUNT=$((NO_PROGRESS_COUNT + 1))
      log "No progress detected (${NO_PROGRESS_COUNT}/${MAX_NO_PROGRESS})"
      update_state "no_progress_count" "$NO_PROGRESS_COUNT"
    else
      NO_PROGRESS_COUNT=0
      update_state "no_progress_count" "0"
    fi
  fi
}

# ─── Main Loop ───────────────────────────────────────────────────
log "FORGE Loop Starting"
log "   Task: ${TASK}"
log "   Max iterations: ${MAX_ITERATIONS}"
log "   Cost cap: \$${COST_CAP}"
log "   Sandbox: ${SANDBOX}"
log "   Mode: ${MODE}"
log "   Rate limit: ${RATE_LIMIT}/hour"
log "   Completion: ${COMPLETION_PROMISE}"
log "   State dir: ${STATE_DIR}"
log "   Fix plan: ${FIX_PLAN}"

LOOP_RESULT="max_iterations"

while [ "$ITERATION" -lt "$MAX_ITERATIONS" ]; do
  ITERATION=$((ITERATION + 1))
  log "--- Iteration ${ITERATION}/${MAX_ITERATIONS} ---"
  update_state "iteration" "$ITERATION"

  # Safety checks (3 circuit breakers + cost cap)
  if ! check_cost_cap; then LOOP_RESULT="cost_cap"; break; fi
  if ! check_consecutive_errors; then LOOP_RESULT="circuit_breaker_errors"; break; fi
  if ! check_no_progress; then LOOP_RESULT="circuit_breaker_no_progress"; break; fi
  if ! check_same_output; then LOOP_RESULT="circuit_breaker_same_output"; break; fi

  # Rate limiting
  rate_limit_wait

  # HITL confirmation every 5 iterations in hitl/pair mode
  if [ "$MODE" != "afk" ] && [ $((ITERATION % 5)) -eq 0 ]; then
    if ! hitl_confirm "Iteration ${ITERATION}/${MAX_ITERATIONS}. Errors: ${CONSECUTIVE_ERRORS}. Continue?"; then
      log "User paused at iteration ${ITERATION}"
      LOOP_RESULT="user_paused"
      break
    fi
  fi

  # Git checkpoint
  checkpoint

  # Generate prompt
  generate_prompt

  # Run Claude Code CLI and capture output
  log "Running Claude Code iteration..."
  rm -f "$OUTPUT_FILE"

  if claude --print --output-format text -p "$(cat PROMPT.md)" > "$OUTPUT_FILE" 2>&1; then
    log "Claude iteration completed"
    append_history "iteration" "success"
  else
    exit_code=$?
    log "Claude exited with code $exit_code"
    append_history "iteration" "exit_code=$exit_code"
    # Exit code 2 = stop hook (autonomous loop pattern)
    if [ "$exit_code" -eq 2 ]; then
      log "Stop hook detected (exit code 2)"
      # Continue loop — this is the autonomous iteration pattern
    fi
  fi

  # Analyze output for completion, errors, progress
  analyze_output

  # Break if completed or blocked
  if [ "$LOOP_RESULT" = "completed" ] || [ "$LOOP_RESULT" = "blocked" ]; then
    break
  fi
done

if [ "$ITERATION" -ge "$MAX_ITERATIONS" ] && [ "$LOOP_RESULT" = "max_iterations" ]; then
  log "Max iterations (${MAX_ITERATIONS}) reached. Loop stopped."
  update_state "status" "\"max_iterations\""
fi

# ─── Summary ─────────────────────────────────────────────────────
log "=== FORGE Loop Summary ==="
log "   Result: ${LOOP_RESULT}"
log "   Iterations: ${ITERATION}/${MAX_ITERATIONS}"
log "   Consecutive errors: ${CONSECUTIVE_ERRORS}"
log "   No-progress count: ${NO_PROGRESS_COUNT}"
log "   Same-output count: ${SAME_OUTPUT_COUNT}"
log "   Mode: ${MODE}"

# Final state update
update_state "status" "\"${LOOP_RESULT}\""
update_state "iteration" "$ITERATION"

# Cleanup
rm -f PROMPT.md
cleanup_monitor
log "Full log: ${LOG_FILE}"
log "State: ${STATE_FILE}"
