#!/usr/bin/env bash
# FORGE Hooks -- Complete setup script (v1.9.0+)
# Installs ALL FORGE hooks into ~/.claude/hooks/ and patches ~/.claude/settings.json.
#
# Hooks installed:
#   1. bash-interceptor.js    -- PreToolUse[Bash]      -- Blocks dangerous commands + rewrites verbose output
#   2. token-saver.sh         -- Execution script       -- Filters verbose output to save tokens
#   3. forge-update-check.sh  -- SessionStart           -- Notifies of FORGE updates (1x/24h)
#   4. forge-memory-sync.sh   -- Stop                   -- Auto-syncs vector memory on session end
#   5. statusline.sh          -- Status line            -- Persistent FORGE indicator in terminal
#   6. forge-skill-tracker.sh -- PreToolUse[Skill]+Stop -- Tracks active FORGE skill for status line
#
# Removed in v1.6.0:
#   - command-validator.js + output-filter.js (merged into bash-interceptor.js)
#   - PreToolUse[Skill] notification -- unnecessary token cost (replaced by skill-tracker in v1.7.25)
# Removed in v1.9.3:
#   - forge-router-reminder.sh (UserPromptSubmit) -- excessive token cost, user invokes /forge explicitly
#
# Idempotent: safe to run multiple times.
# Called by: install.sh, /forge update
#
# Usage: bash forge-hooks-setup.sh

set -euo pipefail

HOOKS_DIR="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"

echo "  FORGE Hooks -- Installing hook infrastructure..."
mkdir -p "$HOOKS_DIR"

# ═══════════════════════════════════════════════════════════════════════════════
# 1. bash-interceptor.js -- PreToolUse[Bash] -- Security + token optimization
# ═══════════════════════════════════════════════════════════════════════════════
cat > "$HOOKS_DIR/bash-interceptor.js" << 'INTERCEPTOREOF'
#!/usr/bin/env node
/**
 * bash-interceptor.js -- Unified PreToolUse hook for Bash
 *
 * Combines command validation (block dangerous commands) and
 * output filtering (rewrite verbose commands through RTK or token-saver.sh).
 *
 * Priority: RTK (if installed) > token-saver.sh (fallback)
 *
 * Exit 0 = allow (with optional rewrite via stdout JSON)
 * Exit 2 = block (reason on stderr)
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const TOKEN_SAVER = path.join(process.env.HOME, '.claude', 'hooks', 'token-saver.sh');

// --- Detect RTK (cached for process lifetime) ---

let _rtkPath = undefined;
function getRtkPath() {
  if (_rtkPath !== undefined) return _rtkPath;
  try {
    _rtkPath = execSync('which rtk', { encoding: 'utf8', timeout: 500 }).trim();
  } catch {
    _rtkPath = null;
  }
  return _rtkPath;
}

// --- BLOCKED PATTERNS (dangerous commands) ---

const BLOCKED_PATTERNS = [
  /rm\s+(-rf?|--recursive)\s+[\/~]/i,
  /rm\s+-rf?\s+\//i,
  /rm\s+-rf?\s+~/i,
  /rm\s+-rf?\s+\.\.\//i,
  /sudo\s+rm\s+-rf?\s+\//i,
  />\s*\/dev\/sd[a-z]/i,
  /dd\s+if=.*of=\/dev\/sd/i,
  /mkfs\.\w+\s+\/dev\/sd/i,
  /chmod\s+(-R\s+)?777\s+\//i,
  /chown\s+-R\s+.*\s+\//i,
  /:\(\)\{\s*:\|:&\s*\};:/,
  /while\s+true;\s*do/i,
  /curl.*\|\s*(sudo\s+)?bash/i,
  /wget.*\|\s*(sudo\s+)?bash/i,
  /unset\s+(PATH|HOME|USER)/i,
  /export\s+PATH\s*=\s*$/i,
  /DROP\s+DATABASE/i,
  /DROP\s+TABLE\s+\*/i,
  /TRUNCATE\s+TABLE/i,
  /DELETE\s+FROM\s+\w+\s*;?\s*$/i,
  /git\s+push\s+--force\s+origin\s+main/i,
  /git\s+push\s+-f\s+origin\s+main/i,
  /git\s+reset\s+--hard\s+HEAD~\d{2,}/i,
  /ssh.*rm\s+-rf/i,
];

// --- FILTERED COMMANDS (rewrite through RTK or token-saver) ---

const FILTERED_COMMANDS = new Set([
  'git status', 'git diff', 'git log',
  'git add', 'git commit', 'git push', 'git pull', 'git fetch',
  'git checkout', 'git merge', 'git rebase',
  'npm test', 'npm install', 'npx jest', 'npx vitest',
  'pnpm test', 'pnpm install', 'pnpm add', 'pnpm run',
  'yarn test', 'yarn install',
  'bun test', 'bun install',
  'pip install', 'pytest', 'python -m',
  'go test',
  'cargo test', 'cargo build',
  'docker build',
  'make test', 'make',
  'mvn test', 'mvn install',
  'gradle test', 'gradle build',
  'dotnet test', 'dotnet build',
  'swift test', 'swift build',
  'tsc',
]);

function shouldFilter(command) {
  const trimmed = command.trim();
  if (/[|;&`]|\$\(/.test(trimmed)) return false;

  const words = trimmed.split(/\s+/);
  const key2 = words.slice(0, 2).join(' ');
  const key1 = words[0];

  if (key2 === 'pnpm run' && words.length >= 3 && !words[2].startsWith('test')) return false;
  if (key2 === 'python -m' && words.length >= 3 && words[2] !== 'pytest') return false;

  return FILTERED_COMMANDS.has(key2) || FILTERED_COMMANDS.has(key1);
}

// --- MAIN ---

if (require.main === module) {
  try {
    const input = fs.readFileSync(0, 'utf8');
    const data = JSON.parse(input);
    const command = (data?.tool_input?.command || '').trim();

    if (!command) process.exit(0);

    // Step 1: Check for dangerous commands
    for (const pattern of BLOCKED_PATTERNS) {
      if (pattern.test(command)) {
        process.stderr.write(`Commande dangereuse bloquee : ${pattern}\n`);
        process.exit(2);
      }
    }

    // Step 2: Rewrite verbose commands for token optimization
    if (shouldFilter(command)) {
      const rtk = getRtkPath();
      if (rtk) {
        // RTK handles compression natively -- prefix with rtk
        process.stdout.write(JSON.stringify({
          updatedInput: { command: `rtk ${command}` }
        }));
      } else {
        // Fallback to token-saver.sh
        const escaped = command.replace(/'/g, "'\\''");
        process.stdout.write(JSON.stringify({
          updatedInput: { command: `${TOKEN_SAVER} '${escaped}'` }
        }));
      }
    }

    process.exit(0);
  } catch {
    process.exit(0);
  }
}
INTERCEPTOREOF
echo "    Created bash-interceptor.js"

# ═══════════════════════════════════════════════════════════════════════════════
# 2. token-saver.sh -- Execution script for output filtering
# ═══════════════════════════════════════════════════════════════════════════════
cat > "$HOOKS_DIR/token-saver.sh" << 'SAVEREOF'
#!/usr/bin/env bash
# Token Saver -- Execute command and filter verbose output
# Fallback for when RTK is not installed.
#
# Usage: token-saver.sh '<command>'
# Executes the command, filters output based on known patterns,
# preserves exit code.

set -o pipefail

MAX_LINES=200

CMD="$1"

if [ -z "$CMD" ]; then
  echo "Usage: token-saver.sh '<command>'" >&2
  exit 1
fi

# Execute command, capture output and exit code
OUTPUT=$(bash -c "$CMD" 2>&1)
EXIT_CODE=$?

# Short output -- no point filtering
LINE_COUNT=$(printf '%s\n' "$OUTPUT" | wc -l)
if [ "$LINE_COUNT" -lt 5 ]; then
  printf '%s\n' "$OUTPUT"
  exit $EXIT_CODE
fi

# Extract first two words for filter selection
read -r WORD1 WORD2 _ <<< "$CMD"
KEY="${WORD1}:${WORD2}"

FILTERED=""

case "$KEY" in
  git:status)
    FILTERED=$(printf '%s\n' "$OUTPUT" | grep -E '(^On branch|^Your branch|^\t|^Changes|^Untracked|^nothing|modified:|new file:|deleted:|renamed:|^\?\?|^ [MADRCU?])')
    ;;
  git:diff)
    FILTERED=$(printf '%s\n' "$OUTPUT" | grep -E '(^diff |^---|^\+\+\+|^@@|^[-+])' | head -n "$MAX_LINES")
    TOTAL=$(printf '%s\n' "$OUTPUT" | grep -cE '(^diff |^---|^\+\+\+|^@@|^[-+])' || true)
    if [ "$TOTAL" -gt "$MAX_LINES" ]; then
      FILTERED="$FILTERED
... ($((TOTAL - MAX_LINES)) more lines truncated)"
    fi
    ;;
  git:log)
    # Keep commit hash + date + message (one-line format)
    FILTERED=$(printf '%s\n' "$OUTPUT" | awk '
      /^commit [0-9a-f]+/{hash=$2; next}
      /^Date:/{gsub(/^Date:\s+/,""); date=$0; next}
      /^Author:/{next}
      /^$/{next}
      /^    /{sub(/^    /,""); if(hash){printf "%s %s %s\n",substr(hash,1,7),date,$0; hash=""}}
    ')
    ;;
  git:add|git:commit|git:push|git:pull|git:fetch|git:checkout|git:merge|git:rebase)
    # Ultra-compact: just summary lines
    FILTERED=$(printf '%s\n' "$OUTPUT" | grep -vE '(^\s*$|^remote:|Counting|Compressing|Writing|Total|Resolving|Unpacking)' | head -n 10)
    ;;
  npm:test|npx:jest|npx:vitest|pnpm:test|pnpm:run|yarn:test|bun:test)
    FILTERED=$(printf '%s\n' "$OUTPUT" | grep -E '(^PASS |^FAIL |Test Suites:|Tests:|Snapshots:|Time:|Test Files|Duration|^TOTAL|^ERR!|ELIFECYCLE|exit code)')
    if printf '%s\n' "$OUTPUT" | grep -qE '(^FAIL |Tests:.*failed|Test Suites:.*failed)'; then
      FAIL_DETAILS=$(printf '%s\n' "$OUTPUT" | grep -E '(Expected:|Received:|at Object|> [0-9]+ \||^\s+\^|FAIL |● )' | head -n 60)
      if [ -n "$FAIL_DETAILS" ]; then
        FILTERED="$FILTERED
$FAIL_DETAILS"
      fi
    fi
    ;;
  npm:install|pnpm:install|pnpm:add|yarn:install|bun:install)
    FILTERED=$(printf '%s\n' "$OUTPUT" | grep -E '(added|removed|changed|packages|up to date|audited|vulnerabilities|WARN|ERR!|Progress:|Done in|Resolved|Installed)')
    ;;
  pip:install)
    FILTERED=$(printf '%s\n' "$OUTPUT" | grep -E '(Successfully installed|already satisfied|ERROR|WARNING|Collecting|Installing)')
    ;;
  pytest:*|python:-m)
    FILTERED=$(printf '%s\n' "$OUTPUT" | grep -E '(^tests/.*PASSED|^tests/.*FAILED|^tests/.*ERROR|PASSED|FAILED|ERROR|warnings? summary|short test summary|=====|^FAILED |^E )')
    ;;
  go:test)
    FILTERED=$(printf '%s\n' "$OUTPUT" | grep -E '(^ok|^FAIL|^---|^panic|PASS|SKIP)')
    ;;
  cargo:test)
    FILTERED=$(printf '%s\n' "$OUTPUT" | grep -E '(^test |test result|^running|^failures|FAILED|^error)')
    ;;
  cargo:build)
    FILTERED=$(printf '%s\n' "$OUTPUT" | grep -E '(^error|^warning|Compiling|Finished|could not compile)')
    ;;
  docker:build)
    FILTERED=$(printf '%s\n' "$OUTPUT" | grep -E '(^Step |^Successfully|^ERROR|^#[0-9]|FINISHED|CACHED|exporting to image|error:)')
    ;;
  make:*|make:test)
    FILTERED=$(printf '%s\n' "$OUTPUT" | grep -E '(^make|Error|error:|warning:|PASS|FAIL|^gcc|^g\+\+|^cc|Nothing to be done|is up to date)')
    ;;
  mvn:test|mvn:install)
    FILTERED=$(printf '%s\n' "$OUTPUT" | grep -E '(BUILD SUCCESS|BUILD FAILURE|Tests run:|^\[ERROR\]|^\[WARNING\]|^Failed tests:|^Tests in error:|\[INFO\] ---)')
    ;;
  gradle:test|gradle:build)
    FILTERED=$(printf '%s\n' "$OUTPUT" | grep -E '(BUILD SUCCESSFUL|BUILD FAILED|tests completed|FAILURE:|> Task|^e:|actionable task)')
    ;;
  dotnet:test)
    FILTERED=$(printf '%s\n' "$OUTPUT" | grep -E '(Passed!|Failed!|Total tests|Passed|Failed|Skipped|error |warning )')
    ;;
  dotnet:build)
    FILTERED=$(printf '%s\n' "$OUTPUT" | grep -E '(Build succeeded|Build FAILED|error |warning |-> )')
    ;;
  swift:test)
    FILTERED=$(printf '%s\n' "$OUTPUT" | grep -E '(Test Case|Test Suite|passed|failed|Executed|error:)')
    ;;
  swift:build)
    FILTERED=$(printf '%s\n' "$OUTPUT" | grep -E '(Build complete|error:|warning:|Compiling|Linking)')
    ;;
  tsc:*)
    FILTERED=$(printf '%s\n' "$OUTPUT" | grep -E '(error TS|: error|Found [0-9]+ error)')
    ;;
  *)
    printf '%s\n' "$OUTPUT"
    exit $EXIT_CODE
    ;;
esac

# Fallback: if filter produced empty output, return original (fail open)
if [ -z "$FILTERED" ]; then
  printf '%s\n' "$OUTPUT"
else
  printf '%s\n' "$FILTERED"
fi

exit $EXIT_CODE
SAVEREOF
chmod +x "$HOOKS_DIR/token-saver.sh"
echo "    Created token-saver.sh"

# ═══════════════════════════════════════════════════════════════════════════════
# 3. forge-update-check.sh -- SessionStart -- Update notifications
# ═══════════════════════════════════════════════════════════════════════════════
cat > "$HOOKS_DIR/forge-update-check.sh" << 'UPDATEEOF'
#!/usr/bin/env bash
# FORGE Update Check -- SessionStart hook
# Silently checks if a newer FORGE version is available (max 1x per 24h).
# Outputs a notification string if update available, empty otherwise.
# Always exits 0 (never blocks session startup).

set -euo pipefail

LOCAL_VERSION_FILE="${HOME}/.claude/skills/forge/.forge-version"
CACHE_FILE="${HOME}/.claude/skills/forge/.forge-update-cache"
REMOTE_URL="https://raw.githubusercontent.com/fwehrling/forge/main/VERSION"
TTL=86400  # 24 hours in seconds

# Not installed -- skip silently
if [ ! -f "$LOCAL_VERSION_FILE" ]; then
    exit 0
fi

# Check cache TTL
if [ -f "$CACHE_FILE" ]; then
    cache_ts=$(head -1 "$CACHE_FILE" 2>/dev/null || echo "0")
    now=$(date +%s)
    elapsed=$(( now - cache_ts ))
    if [ "$elapsed" -lt "$TTL" ]; then
        cached_msg=$(tail -n +2 "$CACHE_FILE" 2>/dev/null || true)
        if [ -n "$cached_msg" ]; then
            echo "$cached_msg"
        fi
        exit 0
    fi
fi

# Fetch remote version (timeout 3s)
remote_version=$(curl -s --max-time 3 "$REMOTE_URL" 2>/dev/null | tr -d '[:space:]') || true

# Validate: must be non-empty and look like semver
if [ -z "$remote_version" ] || ! echo "$remote_version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+'; then
    exit 0
fi

local_version=$(tr -d '[:space:]' < "$LOCAL_VERSION_FILE")

# Compare versions
now=$(date +%s)
if [ "$local_version" != "$remote_version" ]; then
    msg="FORGE update available (v${local_version} -> v${remote_version}). Run /forge update to update."
    printf '%s\n%s\n' "$now" "$msg" > "$CACHE_FILE"
    echo "$msg"
else
    printf '%s\n' "$now" > "$CACHE_FILE"
fi

exit 0
UPDATEEOF
chmod +x "$HOOKS_DIR/forge-update-check.sh"
echo "    Created forge-update-check.sh"

# ═══════════════════════════════════════════════════════════════════════════════
# 3b. forge-slim.sh -- SessionStart -- Auto-activate compressed output mode
# ═══════════════════════════════════════════════════════════════════════════════
cat > "$HOOKS_DIR/forge-slim.sh" << 'SLIMEOF'
#!/usr/bin/env bash
# FORGE Slim -- SessionStart hook
# Activates compressed French output mode to reduce output tokens ~70%.
# Always exits 0 (never blocks session startup).

# Only activate if forge-slim skill is installed
if [ ! -f "$HOME/.forge/skills/forge-slim/SKILL.md" ]; then
    exit 0
fi

cat << 'MSG'
FORGE-SLIM active (lite). Réponses en français concis, accents obligatoires. Pas de remplissage ni hésitation. Articles conservés, phrases complètes. Professionnel mais serré. Mode document pour livrables (français impeccable). /forge-slim lite|full|ultra pour changer. "stop slim" pour désactiver.
MSG

exit 0
SLIMEOF
chmod +x "$HOOKS_DIR/forge-slim.sh"
echo "    Created forge-slim.sh"

# ═══════════════════════════════════════════════════════════════════════════════
# 4. forge-memory-sync.sh -- Stop -- Memory persistence
# ═══════════════════════════════════════════════════════════════════════════════
cat > "$HOOKS_DIR/forge-memory-sync.sh" << 'MEMORYEOF'
#!/usr/bin/env bash
# FORGE Memory -- Auto-sync hook for Claude Code Stop event.
# Detects if the current project uses FORGE and:
#   1. Consolidates session logs into MEMORY.md
#   2. Syncs the vector memory index
# Non-blocking, silent -- always exits 0.

(
  dir="$PWD"
  while [ "$dir" != "/" ]; do
    if [ -d "$dir/.forge/memory" ]; then
      cd "$dir" || break
      forge-memory consolidate 2>/dev/null
      forge-memory sync 2>/dev/null
      break
    fi
    dir="$(dirname "$dir")"
  done
) &>/dev/null &

exit 0
MEMORYEOF
chmod +x "$HOOKS_DIR/forge-memory-sync.sh"
echo "    Created forge-memory-sync.sh"

# ═══════════════════════════════════════════════════════════════════════════════
# 5b. forge-skill-tracker.sh -- Tracks active FORGE skill for status line
# ═══════════════════════════════════════════════════════════════════════════════
cat > "$HOOKS_DIR/forge-skill-tracker.sh" << 'SKILLTRACKEREOF'
#!/bin/bash
# FORGE Skill Tracker -- writes/clears active forge skill to temp file
# Called by PreToolUse[Skill] and Stop hooks
# Usage: forge-skill-tracker.sh pre|post|clear
#
# The indicator persists after Skill tool returns because the actual work
# happens AFTER the tool completes. It gets overwritten by the next forge
# skill or cleared explicitly via "clear" (called by Stop hook).

input=$(cat)
ACTION="$1"
CWD_HASH=$(printf '%s' "${PWD}" | shasum -a 256 | cut -c1-8)
SKILL_FILE="/tmp/forge-active-skill-${CWD_HASH}"

SKILL_NAME=$(echo "$input" | jq -r '.tool_input.skill // empty' 2>/dev/null)

case "$ACTION" in
  pre)
    # Only track forge-* skills (not google-calendar, find-skills, etc.)
    if [[ "$SKILL_NAME" == forge* ]]; then
      echo "$SKILL_NAME" > "$SKILL_FILE"
    fi
    ;;
  post)
    # Do NOT clear on PostToolUse -- the skill's work continues after
    # the Skill tool returns "Successfully loaded skill".
    # The file gets overwritten by the next forge skill invocation,
    # or cleared on session Stop.
    :
    ;;
  clear)
    # Explicit cleanup (called by Stop hook)
    rm -f "$SKILL_FILE" 2>/dev/null
    ;;
esac

echo '{"suppressOutput": true}'
SKILLTRACKEREOF
chmod +x "$HOOKS_DIR/forge-skill-tracker.sh"
echo "    Created forge-skill-tracker.sh"

# Clean up old forge-router-reminder.sh if present
rm -f "$HOOKS_DIR/forge-router-reminder.sh"

# ═══════════════════════════════════════════════════════════════════════════════
# 6. statusline.sh -- FORGE status line indicator
# ═══════════════════════════════════════════════════════════════════════════════
INSTALL_STATUSLINE=false

# Check if user already has a non-FORGE statusLine configured
EXISTING_STATUSLINE=""
if [ -f "$SETTINGS" ]; then
  EXISTING_STATUSLINE=$(node -e "
    const s = JSON.parse(require('fs').readFileSync('$SETTINGS', 'utf8'));
    if (s.statusLine && s.statusLine.command && !s.statusLine.command.includes('statusline.sh')) {
      process.stdout.write(s.statusLine.command);
    }
  " 2>/dev/null || true)
fi

# Show what the status line provides and ask
echo ""
echo "  FORGE Status Line (optional):"
echo "    Adds a persistent indicator in the Claude Code terminal bar:"
echo "    [Model] FORGE v1.x.x project-name | CTX:42% | 5h:67% (reset 2h30m) | 7d:12% (reset 5d3h)"
echo "    - Model name and project detection"
echo "    - FORGE marker when .forge/ is detected"
echo "    - Context window usage (with warning at 30%/50%)"
echo "    - Rate limits: 5-hour and 7-day windows with reset countdown"
echo ""

if [ -n "$EXISTING_STATUSLINE" ]; then
  echo "    Note: You already have a status line configured:"
  echo "      $EXISTING_STATUSLINE"
  echo "    Installing FORGE status line will replace it."
  echo ""
fi

# Interactive prompt (auto-yes, skip if non-interactive)
if [ "${FORGE_AUTO:-}" = "true" ]; then
  INSTALL_STATUSLINE=true
elif [ -t 0 ]; then
  printf "  Install FORGE status line? [y/N] "
  read -r REPLY < /dev/tty
  case "$REPLY" in
    [yY]|[yY][eE][sS]) INSTALL_STATUSLINE=true ;;
  esac
else
  echo "    (Non-interactive mode: skipping status line installation)"
  echo "    Run 'bash ~/.claude/skills/forge/scripts/forge-hooks-setup.sh' interactively to install it."
fi

if [ "$INSTALL_STATUSLINE" = true ]; then
cat > "$HOOKS_DIR/statusline.sh" << 'STATUSLINEEOF'
#!/bin/bash
# FORGE Status Line -- persistent indicator in Claude Code terminal
# Reads JSON context from stdin, outputs status text
input=$(cat)
MODEL=$(echo "$input" | jq -r '.model.display_name // "Claude"' 2>/dev/null)
CWD=$(echo "$input" | jq -r '.workspace.current_dir // ""' 2>/dev/null)
PROJECT=$(basename "$CWD" 2>/dev/null)

# ANSI color codes (defined early -- used by burn rate indicator and context display)
RED='\033[31m'
ORANGE='\033[38;5;208m'
GREEN='\033[32m'
RESET='\033[0m'

# Rate limits: 5-hour window
FIVE_PCT=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' 2>/dev/null)
FIVE_RESET=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty' 2>/dev/null)

# Rate limits: 7-day window
WEEK_PCT=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty' 2>/dev/null)
WEEK_RESET=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty' 2>/dev/null)

# Build rate limit display
RATE_PARTS=""

if [ -n "$FIVE_PCT" ] && [ -n "$FIVE_RESET" ]; then
    NOW=$(date +%s)
    DIFF=$(( FIVE_RESET - NOW ))
    if [ "$DIFF" -le 0 ]; then
        FIVE_REMAINING="resets now"
    else
        FIVE_H=$(( DIFF / 3600 ))
        FIVE_M=$(( (DIFF % 3600) / 60 ))
        if [ "$FIVE_H" -gt 0 ]; then
            FIVE_REMAINING="${FIVE_H}h${FIVE_M}m"
        else
            FIVE_REMAINING="${FIVE_M}m"
        fi
    fi
    FIVE_INT=$(printf '%.0f' "$FIVE_PCT")

    # Burn rate indicator: red triangle if usage exceeds expected rate + 5% tolerance
    BURN_ICON=""
    WIN_START=$(( FIVE_RESET - 18000 ))  # 5h = 18000s
    ELAPSED=$(( NOW - WIN_START ))
    if [ "$ELAPSED" -gt 0 ]; then
        ELAPSED_HOURS_X100=$(( ELAPSED * 100 / 3600 ))   # elapsed hours * 100 (integer math)
        EXPECTED_X100=$(( ELAPSED_HOURS_X100 * 20 ))      # expected% * 100
        ACTUAL_X100=$(( FIVE_INT * 100 ))
        TOLERANCE=500  # 5% margin (in X100 units)
        if [ "$ACTUAL_X100" -gt "$(( EXPECTED_X100 + TOLERANCE ))" ] 2>/dev/null; then
            BURN_ICON="${RED}$(printf '\xe2\x96\xb2')${RESET} "
        fi
    fi

    RATE_PARTS="${BURN_ICON}5h:${FIVE_INT}% (reset ${FIVE_REMAINING})"
fi

if [ -n "$WEEK_PCT" ] && [ -n "$WEEK_RESET" ]; then
    NOW=$(date +%s)
    DIFF=$(( WEEK_RESET - NOW ))
    if [ "$DIFF" -le 0 ]; then
        WEEK_REMAINING="resets now"
    else
        WEEK_D=$(( DIFF / 86400 ))
        WEEK_H=$(( (DIFF % 86400) / 3600 ))
        WEEK_M=$(( (DIFF % 3600) / 60 ))
        if [ "$WEEK_D" -gt 0 ]; then
            WEEK_REMAINING="${WEEK_D}d${WEEK_H}h"
        elif [ "$WEEK_H" -gt 0 ]; then
            WEEK_REMAINING="${WEEK_H}h${WEEK_M}m"
        else
            WEEK_REMAINING="${WEEK_M}m"
        fi
    fi
    WEEK_INT=$(printf '%.0f' "$WEEK_PCT")
    if [ -n "$RATE_PARTS" ]; then
        RATE_PARTS="${RATE_PARTS} | 7d:${WEEK_INT}% (reset ${WEEK_REMAINING})"
    else
        RATE_PARTS="7d:${WEEK_INT}% (reset ${WEEK_REMAINING})"
    fi
fi

# Unicode icons (via printf for portable encoding)
ICON_HIGH=$(printf '\xe2\x98\xa0')  # ☠
ICON_MED=$(printf '\xe2\x9a\xa0')   # ⚠
ICON_SKILL=$(printf '\xe2\x97\x8f')       # ⚙

# Context window usage with colored icons
USED_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' 2>/dev/null)
USED_PCT=${USED_PCT%.*}  # truncate to integer

if [ "$USED_PCT" -ge 50 ] 2>/dev/null; then
    CTX="${RED}${ICON_HIGH}${RESET} CTX:${USED_PCT}%"
elif [ "$USED_PCT" -ge 30 ] 2>/dev/null; then
    CTX="${ORANGE}${ICON_MED}${RESET} CTX:${USED_PCT}%"
else
    CTX="CTX:${USED_PCT}%"
fi

# Build final status line
FORGE_MARKER=""
if [ -d "$CWD/.forge" ]; then
    FORGE_VER=""
    if [ -f "$HOME/.claude/skills/forge/.forge-version" ]; then
        FORGE_VER=" v$(cat "$HOME/.claude/skills/forge/.forge-version" | tr -d '[:space:]')"
    fi
    FORGE_MARKER=" [FORGE${FORGE_VER}]"
fi

# Active FORGE skill indicator (scoped per project via CWD hash)
SKILL_INDICATOR=""
CWD_HASH=$(printf '%s' "${CWD}" | shasum -a 256 | cut -c1-8)
SKILL_FILE="/tmp/forge-active-skill-${CWD_HASH}"
if [ -f "$SKILL_FILE" ]; then
    ACTIVE_SKILL=$(cat "$SKILL_FILE" 2>/dev/null)
    if [ -n "$ACTIVE_SKILL" ]; then
        SKILL_INDICATOR=" ${GREEN}${ICON_SKILL}${RESET} ${ACTIVE_SKILL}"
    fi
fi

PARTS="${CTX}"
if [ -n "$RATE_PARTS" ]; then
    PARTS="${CTX} | ${RATE_PARTS}"
fi

# User customizations -- sourced before output, survives FORGE updates
# Available vars: MODEL, FORGE_MARKER, SKILL_INDICATOR, PROJECT, CTX, PARTS, RATE_PARTS
# Add-on vars (init here so user script can set them): EFFORT_LABEL
EFFORT_LABEL=""
if [ -f "$HOME/.claude/hooks/statusline-custom.sh" ]; then
    source "$HOME/.claude/hooks/statusline-custom.sh"
fi

printf '%b\n' "[${MODEL}${EFFORT_LABEL}]${FORGE_MARKER}${SKILL_INDICATOR} ${PROJECT} | ${PARTS}"
STATUSLINEEOF
chmod +x "$HOOKS_DIR/statusline.sh"
echo "    Created statusline.sh"
else
  echo "    Skipped statusline.sh (user declined)"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# 7. Clean up legacy hooks from pre-v1.6.0
# ═══════════════════════════════════════════════════════════════════════════════
echo "  Cleaning up legacy hooks..."
for legacy_file in command-validator.js output-filter.js forge-auto-router.js; do
  if [ -f "$HOOKS_DIR/$legacy_file" ]; then
    rm -f "$HOOKS_DIR/$legacy_file"
    echo "    Removed legacy $legacy_file"
  fi
done

# ═══════════════════════════════════════════════════════════════════════════════
# 8. Patch settings.json -- Register hooks + permissions + status line
# ═══════════════════════════════════════════════════════════════════════════════
echo "  Patching settings.json..."

if [ ! -f "$SETTINGS" ]; then
  echo '{}' > "$SETTINGS"
fi

SETTINGS_ESCAPED=$(printf '%s' "$SETTINGS" | sed "s/'/\\\\'/g")
node -e "
const fs = require('fs');
const settingsPath = '${SETTINGS_ESCAPED}';
const s = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));

// -- Permissions --
if (!s.permissions) s.permissions = {};
if (!s.permissions.allow) s.permissions.allow = [];

const requiredPerms = [
  'Bash(~/.claude/hooks/token-saver.sh *)'
];
for (const perm of requiredPerms) {
  if (!s.permissions.allow.includes(perm)) {
    s.permissions.allow.push(perm);
  }
}

// -- Hooks --
if (!s.hooks) s.hooks = {};

// Helper: ensure a hook entry exists for event+matcher
function ensureHookEntry(event, matcher) {
  if (!s.hooks[event]) s.hooks[event] = [];
  let entry = s.hooks[event].find(h => h.matcher === matcher);
  if (!entry) {
    entry = { matcher, hooks: [] };
    s.hooks[event].push(entry);
  }
  if (!entry.hooks) entry.hooks = [];
  return entry.hooks;
}

// Helper: add a command hook if not already present
function addCommandHook(event, matcher, command, extra) {
  const hooks = ensureHookEntry(event, matcher);
  if (!hooks.some(h => h.command === command)) {
    hooks.push({ type: 'command', command, ...extra });
  }
}

// -- Remove legacy hooks --
// Remove old PreToolUse[Bash] hooks (command-validator.js, output-filter.js)
if (s.hooks.PreToolUse) {
  for (const entry of s.hooks.PreToolUse) {
    if (entry.matcher === 'Bash' && entry.hooks) {
      entry.hooks = entry.hooks.filter(h =>
        !h.command?.includes('command-validator.js') &&
        !h.command?.includes('output-filter.js')
      );
    }
  }
}

// Remove all UserPromptSubmit hooks (forge-router-reminder removed in v1.9.3)
if (s.hooks.UserPromptSubmit) {
  delete s.hooks.UserPromptSubmit;
}

// Remove old PreToolUse[Skill] notification hooks (but keep skill-tracker)
if (s.hooks.PreToolUse) {
  for (const entry of s.hooks.PreToolUse) {
    if (entry.matcher === 'Skill' && entry.hooks) {
      entry.hooks = entry.hooks.filter(h =>
        h.command?.includes('forge-skill-tracker.sh') ||
        (!h.command?.includes('forge') && !h.statusMessage?.includes('FORGE'))
      );
    }
  }
  s.hooks.PreToolUse = s.hooks.PreToolUse.filter(e =>
    e.hooks && e.hooks.length > 0
  );
}

// -- Add current hooks --

// PreToolUse[Bash] -- bash-interceptor.js (unified security + token optimization)
const bashHooks = ensureHookEntry('PreToolUse', 'Bash');
const interceptorCmd = 'node ~/.claude/hooks/bash-interceptor.js';
if (!bashHooks.some(h => h.command === interceptorCmd)) {
  bashHooks.unshift({ type: 'command', command: interceptorCmd });
}

// SessionStart -- forge-update-check.sh
addCommandHook('SessionStart', '', 'bash ~/.claude/hooks/forge-update-check.sh');

// SessionStart -- forge-slim.sh (compressed output mode)
addCommandHook('SessionStart', '', 'bash ~/.claude/hooks/forge-slim.sh');

// Stop -- forge-memory-sync.sh
addCommandHook('Stop', '', 'bash ~/.claude/hooks/forge-memory-sync.sh');

// PreToolUse[Skill] -- forge-skill-tracker.sh (active skill indicator)
addCommandHook('PreToolUse', 'Skill', 'bash ~/.claude/hooks/forge-skill-tracker.sh pre');

// PostToolUse[Skill] -- forge-skill-tracker.sh (no-op, kept for future use)
addCommandHook('PostToolUse', 'Skill', 'bash ~/.claude/hooks/forge-skill-tracker.sh post');

// Stop -- forge-skill-tracker.sh clear (cleanup active skill indicator)
addCommandHook('Stop', '', 'bash ~/.claude/hooks/forge-skill-tracker.sh clear');

// -- Status Line (only if user accepted) --
if ('${INSTALL_STATUSLINE}' === 'true') {
  if (!s.statusLine || !s.statusLine.command?.includes('statusline.sh')) {
    s.statusLine = {
      type: 'command',
      command: 'bash ~/.claude/hooks/statusline.sh'
    };
  }
}

fs.writeFileSync(settingsPath, JSON.stringify(s, null, 2) + '\n');
" 2>/dev/null && echo "    Patched settings.json with FORGE hooks" || echo "    Could not patch settings.json (update manually)"

echo ""
echo "  FORGE Hooks -- Installation complete!"
if [ "$INSTALL_STATUSLINE" = true ]; then
  echo "     7 hook scripts in ~/.claude/hooks/"
  echo "     5 hook events + status line in ~/.claude/settings.json"
else
  echo "     6 hook scripts in ~/.claude/hooks/"
  echo "     5 hook events in ~/.claude/settings.json"
fi
echo "     (PreToolUse[Bash|Skill], PostToolUse[Skill], SessionStart, Stop)"
