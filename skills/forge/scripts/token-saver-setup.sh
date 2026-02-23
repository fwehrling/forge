#!/usr/bin/env bash
# Token Saver — Standalone setup script
# Installs output-filter.js + token-saver.sh into ~/.claude/hooks/
# and patches ~/.claude/settings.json.
#
# Idempotent: safe to run multiple times.
# Called by: install.sh, forge-init.sh
#
# Usage: bash token-saver-setup.sh

set -euo pipefail

HOOKS_DIR="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"

echo "  📦 Token Saver — Setting up output filtering..."
mkdir -p "$HOOKS_DIR"

# ── output-filter.js ──────────────────────────────────────────────────────────
if [ ! -f "$HOOKS_DIR/output-filter.js" ]; then
  cat > "$HOOKS_DIR/output-filter.js" << 'FILTEREOF'
/**
 * Token Saver — Output Filter Hook for Claude Code
 *
 * PreToolUse hook for Bash tool.
 * Intercepts known commands and rewrites them to go through token-saver.sh
 * which executes the command and filters verbose output.
 *
 * Exit 0 = passthrough (no rewrite)
 * stdout JSON with updatedInput = rewrite command
 */

const fs = require('fs');
const path = require('path');

const TOKEN_SAVER = path.join(process.env.HOME, '.claude', 'hooks', 'token-saver.sh');

// Commands to filter: matched against first two words of the command
const FILTERED_COMMANDS = new Set([
  // Git
  'git status', 'git diff', 'git log',
  // Node / npm
  'npm test', 'npm install', 'npx jest', 'npx vitest',
  // pnpm
  'pnpm test', 'pnpm install', 'pnpm add', 'pnpm run',
  // Yarn
  'yarn test', 'yarn install',
  // Bun
  'bun test', 'bun install',
  // Python
  'pip install', 'pytest', 'python -m',
  // Go
  'go test',
  // Rust
  'cargo test', 'cargo build',
  // Docker
  'docker build',
  // Make
  'make test', 'make',
  // Java
  'mvn test', 'mvn install', 'gradle test', 'gradle build',
  // .NET
  'dotnet test', 'dotnet build',
  // Swift
  'swift test', 'swift build',
  // TypeScript
  'tsc',
]);

function shouldFilter(command) {
  const trimmed = command.trim();

  // Skip complex commands with pipes, chains, or subshells
  if (/[|;&`]|\$\(/.test(trimmed)) {
    return false;
  }

  // Extract first two words
  const words = trimmed.split(/\s+/);
  const key2 = words.slice(0, 2).join(' ');
  const key1 = words[0];

  // Special case: "pnpm run test" → match "pnpm run" but only if 3rd word starts with "test"
  if (key2 === 'pnpm run' && words.length >= 3 && !words[2].startsWith('test')) {
    return false;
  }

  // Special case: "python -m pytest" → match "python -m" but only if 3rd word is "pytest"
  if (key2 === 'python -m' && words.length >= 3 && words[2] !== 'pytest') {
    return false;
  }

  // Match on two words first, then fall back to single word
  return FILTERED_COMMANDS.has(key2) || FILTERED_COMMANDS.has(key1);
}

if (require.main === module) {
  try {
    const input = fs.readFileSync(0, 'utf8');
    const data = JSON.parse(input);
    const command = data?.tool_input?.command || '';

    if (!command || !shouldFilter(command)) {
      process.exit(0);
    }

    // Rewrite command to go through token-saver.sh
    const escaped = command.replace(/'/g, "'\\''");
    const result = {
      updatedInput: {
        command: `${TOKEN_SAVER} '${escaped}'`
      }
    };

    process.stdout.write(JSON.stringify(result));
    process.exit(0);
  } catch {
    // Fail open — passthrough on any error
    process.exit(0);
  }
}

module.exports = { shouldFilter, FILTERED_COMMANDS };
FILTEREOF
  echo "    ✅ Created output-filter.js"
else
  echo "    ⏭  output-filter.js already exists"
fi

# ── token-saver.sh ───────────────────────────────────────────────────────────
if [ ! -f "$HOOKS_DIR/token-saver.sh" ]; then
  cat > "$HOOKS_DIR/token-saver.sh" << 'SAVEREOF'
#!/usr/bin/env bash
# Token Saver — Execute command and filter verbose output
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

# Short output — no point filtering
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
    # Keep diff headers + hunk markers + changed lines, cap at MAX_LINES
    FILTERED=$(printf '%s\n' "$OUTPUT" | grep -E '(^diff |^---|^\+\+\+|^@@|^[-+])' | head -n "$MAX_LINES")
    TOTAL=$(printf '%s\n' "$OUTPUT" | grep -cE '(^diff |^---|^\+\+\+|^@@|^[-+])' || true)
    if [ "$TOTAL" -gt "$MAX_LINES" ]; then
      FILTERED="$FILTERED
... ($((TOTAL - MAX_LINES)) more lines truncated)"
    fi
    ;;
  git:log)
    # Keep only commit hash + title (first indented line per commit)
    FILTERED=$(printf '%s\n' "$OUTPUT" | awk '/^commit [0-9a-f]/{print;t=1;next} /^(Author|Date):/{next} /^$/{next} t&&/^    /{sub(/^    /,"  ");print;t=0;next}')
    ;;
  npm:test|npx:jest|npx:vitest|pnpm:test|pnpm:run|yarn:test|bun:test)
    # Keep PASS/FAIL per file, errors, and summary — drop individual test lines
    FILTERED=$(printf '%s\n' "$OUTPUT" | grep -E '(^PASS |^FAIL |Test Suites:|Tests:|Snapshots:|Time:|Test Files|Duration|^TOTAL|^ERR!|● |ELIFECYCLE|exit code)')
    # If tests actually failed (check summary line, not test descriptions)
    if printf '%s\n' "$OUTPUT" | grep -qE '(^FAIL |Tests:.*failed|Test Suites:.*failed)'; then
      FAIL_DETAILS=$(printf '%s\n' "$OUTPUT" | grep -E '(● |Expected:|Received:|at Object|> [0-9]+ \||^\s+\^|FAIL )' | head -n 60)
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
    # Keep per-file results + errors + summary — drop individual test lines
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
    # Unknown command — passthrough
    printf '%s\n' "$OUTPUT"
    exit $EXIT_CODE
    ;;
esac

# Fallback: if filter produced empty output, return original
if [ -z "$FILTERED" ]; then
  printf '%s\n' "$OUTPUT"
else
  printf '%s\n' "$FILTERED"
fi

exit $EXIT_CODE
SAVEREOF
  chmod +x "$HOOKS_DIR/token-saver.sh"
  echo "    ✅ Created token-saver.sh"
else
  echo "    ⏭  token-saver.sh already exists"
fi

# ── Patch settings.json ───────────────────────────────────────────────────────
if [ -f "$SETTINGS" ]; then
  node -e "
const fs = require('fs');
const s = JSON.parse(fs.readFileSync('$SETTINGS', 'utf8'));

// Add permission
const perm = 'Bash(~/.claude/hooks/token-saver.sh *)';
if (!s.permissions) s.permissions = {};
if (!s.permissions.allow) s.permissions.allow = [];
if (!s.permissions.allow.includes(perm)) {
  s.permissions.allow.push(perm);
}

// Add hook
if (!s.hooks) s.hooks = {};
if (!s.hooks.PreToolUse) s.hooks.PreToolUse = [];
const bashHook = s.hooks.PreToolUse.find(h => h.matcher === 'Bash');
const hookCmd = 'node ~/.claude/hooks/output-filter.js';
if (bashHook) {
  if (!bashHook.hooks) bashHook.hooks = [];
  if (!bashHook.hooks.some(h => h.command === hookCmd)) {
    bashHook.hooks.push({ type: 'command', command: hookCmd });
  }
} else {
  s.hooks.PreToolUse.push({
    matcher: 'Bash',
    hooks: [{ type: 'command', command: hookCmd }]
  });
}

fs.writeFileSync('$SETTINGS', JSON.stringify(s, null, 2) + '\n');
" 2>/dev/null && echo "    ✅ Patched settings.json" || echo "    ⚠️  Could not patch settings.json (update manually)"
fi

echo "    Done."
