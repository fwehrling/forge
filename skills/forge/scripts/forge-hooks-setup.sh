#!/usr/bin/env bash
# FORGE Hooks — Complete setup script (v1.6.0+)
# Installs ALL FORGE hooks into ~/.claude/hooks/ and patches ~/.claude/settings.json.
#
# Hooks installed:
#   1. bash-interceptor.js  — PreToolUse[Bash]    — Blocks dangerous commands + rewrites verbose output
#   2. token-saver.sh       — Execution script     — Filters verbose output to save tokens
#   3. forge-update-check.sh — SessionStart        — Notifies of FORGE updates (1x/24h)
#   4. forge-memory-sync.sh — Stop                 — Auto-syncs vector memory on session end
#   5. statusline.sh        — Status line          — Persistent FORGE indicator in terminal
#
# Removed in v1.6.0:
#   - command-validator.js + output-filter.js (merged into bash-interceptor.js)
#   - forge-auto-router.js (UserPromptSubmit) — Claude Code native skill matching is sufficient
#   - PreToolUse[Skill] notification — unnecessary token cost
#
# Idempotent: safe to run multiple times.
# Called by: install.sh, /forge-update
#
# Usage: bash forge-hooks-setup.sh

set -euo pipefail

HOOKS_DIR="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"

echo "  FORGE Hooks — Installing hook infrastructure..."
mkdir -p "$HOOKS_DIR"

# ═══════════════════════════════════════════════════════════════════════════════
# 1. bash-interceptor.js — PreToolUse[Bash] — Security + token optimization
# ═══════════════════════════════════════════════════════════════════════════════
cat > "$HOOKS_DIR/bash-interceptor.js" << 'INTERCEPTOREOF'
#!/usr/bin/env node
/**
 * bash-interceptor.js — Unified PreToolUse hook for Bash
 *
 * Combines command validation (block dangerous commands) and
 * output filtering (rewrite verbose commands through token-saver.sh).
 *
 * Exit 0 = allow (with optional rewrite via stdout JSON)
 * Exit 2 = block (reason on stderr)
 */

const fs = require('fs');
const path = require('path');

const TOKEN_SAVER = path.join(process.env.HOME, '.claude', 'hooks', 'token-saver.sh');

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

// --- FILTERED COMMANDS (rewrite through token-saver) ---

const FILTERED_COMMANDS = new Set([
  'git status', 'git diff', 'git log',
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

    // Step 2: Rewrite verbose commands through token-saver
    if (shouldFilter(command)) {
      const escaped = command.replace(/'/g, "'\\''");
      process.stdout.write(JSON.stringify({
        updatedInput: { command: `${TOKEN_SAVER} '${escaped}'` }
      }));
    }

    process.exit(0);
  } catch {
    process.exit(0);
  }
}
INTERCEPTOREOF
echo "    Created bash-interceptor.js"

# ═══════════════════════════════════════════════════════════════════════════════
# 2. token-saver.sh — Execution script for output filtering
# ═══════════════════════════════════════════════════════════════════════════════
cat > "$HOOKS_DIR/token-saver.sh" << 'SAVEREOF'
#!/usr/bin/env bash
# Token Saver -- Execute command and filter verbose output
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
OUTPUT=$(eval "$CMD" 2>&1)
EXIT_CODE=$?

# Short output -- no point filtering
if [ ${#OUTPUT} -lt 80 ]; then
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
    FILTERED=$(printf '%s\n' "$OUTPUT" | awk '/^commit [0-9a-f]+/{print;t=1;next} /^(Author|Date):/{next} /^$/{next} t&&/^    /{sub(/^    /,"  ");print;t=0;next}')
    ;;
  npm:test|npx:jest|npx:vitest|pnpm:test|pnpm:run|yarn:test|bun:test)
    FILTERED=$(printf '%s\n' "$OUTPUT" | grep -E '(^PASS |^FAIL |Test Suites:|Tests:|Snapshots:|Time:|Test Files|Duration|^TOTAL|^ERR!|ELIFECYCLE|exit code)')
    if printf '%s\n' "$OUTPUT" | grep -qE '(^FAIL |Tests:.*failed|Test Suites:.*failed)'; then
      FAIL_DETAILS=$(printf '%s\n' "$OUTPUT" | grep -E '(Expected:|Received:|at Object|> [0-9]+ \||^\s+\^|FAIL )' | head -n 60)
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
  echo "[token-saver] filter returned empty -- showing full output" >&2
else
  printf '%s\n' "$FILTERED"
fi

exit $EXIT_CODE
SAVEREOF
chmod +x "$HOOKS_DIR/token-saver.sh"
echo "    Created token-saver.sh"

# ═══════════════════════════════════════════════════════════════════════════════
# 3. forge-update-check.sh — SessionStart — Update notifications
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
    msg="FORGE update available (v${local_version} -> v${remote_version}). Run /forge-update to update."
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
# 4. forge-memory-sync.sh — Stop — Memory persistence
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
# 5. statusline.sh — FORGE status line indicator
# ═══════════════════════════════════════════════════════════════════════════════
cat > "$HOOKS_DIR/statusline.sh" << 'STATUSLINEEOF'
#!/bin/bash
# FORGE Status Line — persistent indicator in Claude Code terminal
# Reads JSON context from stdin, outputs status text
input=$(cat)
MODEL=$(echo "$input" | jq -r '.model.display_name // "Claude"' 2>/dev/null)
CWD=$(echo "$input" | jq -r '.workspace.current_dir // ""' 2>/dev/null)
PROJECT=$(basename "$CWD" 2>/dev/null)
if [ -d "$CWD/.forge" ]; then
    echo "[$MODEL] FORGE active | $PROJECT"
else
    echo "[$MODEL] $PROJECT"
fi
STATUSLINEEOF
chmod +x "$HOOKS_DIR/statusline.sh"
echo "    Created statusline.sh"

# ═══════════════════════════════════════════════════════════════════════════════
# 6. Clean up legacy hooks from pre-v1.6.0
# ═══════════════════════════════════════════════════════════════════════════════
echo "  Cleaning up legacy hooks..."
for legacy_file in command-validator.js output-filter.js forge-auto-router.js; do
  if [ -f "$HOOKS_DIR/$legacy_file" ]; then
    rm -f "$HOOKS_DIR/$legacy_file"
    echo "    Removed legacy $legacy_file"
  fi
done

# ═══════════════════════════════════════════════════════════════════════════════
# 7. Patch settings.json — Register hooks + permissions + status line
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

// Remove old UserPromptSubmit hooks (forge-auto-router.js)
if (s.hooks.UserPromptSubmit) {
  for (const entry of s.hooks.UserPromptSubmit) {
    if (entry.hooks) {
      entry.hooks = entry.hooks.filter(h =>
        !h.command?.includes('forge-auto-router.js')
      );
    }
  }
  // Remove empty UserPromptSubmit entries
  s.hooks.UserPromptSubmit = s.hooks.UserPromptSubmit.filter(e =>
    e.hooks && e.hooks.length > 0
  );
  if (s.hooks.UserPromptSubmit.length === 0) {
    delete s.hooks.UserPromptSubmit;
  }
}

// Remove old PreToolUse[Skill] notification hooks
if (s.hooks.PreToolUse) {
  s.hooks.PreToolUse = s.hooks.PreToolUse.filter(entry => {
    if (entry.matcher === 'Skill') {
      if (entry.hooks) {
        entry.hooks = entry.hooks.filter(h =>
          !h.command?.includes('forge') && !h.statusMessage?.includes('FORGE')
        );
      }
      return entry.hooks && entry.hooks.length > 0;
    }
    return true;
  });
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

// Stop -- forge-memory-sync.sh
addCommandHook('Stop', '', 'bash ~/.claude/hooks/forge-memory-sync.sh');

// -- Status Line --
if (!s.statusLine || !s.statusLine.command?.includes('statusline.sh')) {
  s.statusLine = {
    type: 'command',
    command: 'bash ~/.claude/hooks/statusline.sh'
  };
}

fs.writeFileSync(settingsPath, JSON.stringify(s, null, 2) + '\n');
" 2>/dev/null && echo "    Patched settings.json with FORGE hooks" || echo "    Could not patch settings.json (update manually)"

echo ""
echo "  FORGE Hooks -- Installation complete!"
echo "     5 hook scripts in ~/.claude/hooks/"
echo "     3 hook events + status line in ~/.claude/settings.json"
echo "     (PreToolUse[Bash], SessionStart, Stop)"
