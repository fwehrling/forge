#!/usr/bin/env bash
# Token Saver -- Standalone setup script (v1.6.0+)
# Installs bash-interceptor.js + token-saver.sh into ~/.claude/hooks/
# and patches ~/.claude/settings.json.
#
# This is a lightweight alternative to forge-hooks-setup.sh that only
# installs token optimization (no update-check, memory-sync, or statusline).
# Used by forge-init when full hook setup is not needed.
#
# Idempotent: safe to run multiple times.
# Called by: forge-init.sh
#
# Usage: bash token-saver-setup.sh

set -euo pipefail

HOOKS_DIR="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"

echo "  Token Saver -- Setting up output filtering..."
mkdir -p "$HOOKS_DIR"

# -- bash-interceptor.js (unified security + token optimization) --------------
cat > "$HOOKS_DIR/bash-interceptor.js" << 'INTERCEPTOREOF'
#!/usr/bin/env node
/**
 * bash-interceptor.js -- Unified PreToolUse hook for Bash
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

if (require.main === module) {
  try {
    const input = fs.readFileSync(0, 'utf8');
    const data = JSON.parse(input);
    const command = (data?.tool_input?.command || '').trim();
    if (!command) process.exit(0);
    for (const pattern of BLOCKED_PATTERNS) {
      if (pattern.test(command)) {
        process.stderr.write(`Commande dangereuse bloquee : ${pattern}\n`);
        process.exit(2);
      }
    }
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

# -- token-saver.sh -----------------------------------------------------------
cat > "$HOOKS_DIR/token-saver.sh" << 'SAVEREOF'
#!/usr/bin/env bash
# Token Saver -- Execute command and filter verbose output
set -o pipefail
MAX_LINES=200
CMD="$1"
if [ -z "$CMD" ]; then echo "Usage: token-saver.sh '<command>'" >&2; exit 1; fi
OUTPUT=$(bash -co pipefail "$CMD" 2>&1)
EXIT_CODE=$?
if [ ${#OUTPUT} -lt 80 ]; then printf '%s\n' "$OUTPUT"; exit $EXIT_CODE; fi
read -r WORD1 WORD2 _ <<< "$CMD"
KEY="${WORD1}:${WORD2}"
FILTERED=""
case "$KEY" in
  git:status) FILTERED=$(printf '%s\n' "$OUTPUT" | grep -E '(^On branch|^Your branch|^\t|^Changes|^Untracked|^nothing|modified:|new file:|deleted:|renamed:|^\?\?|^ [MADRCU?])') ;;
  git:diff) FILTERED=$(printf '%s\n' "$OUTPUT" | grep -E '(^diff |^---|^\+\+\+|^@@|^[-+])' | head -n "$MAX_LINES") ;;
  git:log) FILTERED=$(printf '%s\n' "$OUTPUT" | awk '/^commit [0-9a-f]+/{print;t=1;next} /^(Author|Date):/{next} /^$/{next} t&&/^    /{sub(/^    /,"  ");print;t=0;next}') ;;
  npm:test|npx:jest|npx:vitest|pnpm:test|pnpm:run|yarn:test|bun:test) FILTERED=$(printf '%s\n' "$OUTPUT" | grep -E '(^PASS |^FAIL |Test Suites:|Tests:|Time:|Test Files|Duration|^ERR!)') ;;
  npm:install|pnpm:install|pnpm:add|yarn:install|bun:install) FILTERED=$(printf '%s\n' "$OUTPUT" | grep -E '(added|removed|changed|packages|up to date|audited|vulnerabilities|WARN|ERR!|Done in)') ;;
  pip:install) FILTERED=$(printf '%s\n' "$OUTPUT" | grep -E '(Successfully installed|already satisfied|ERROR|WARNING)') ;;
  pytest:*|python:-m) FILTERED=$(printf '%s\n' "$OUTPUT" | grep -E '(PASSED|FAILED|ERROR|warnings? summary|short test summary|=====|^E )') ;;
  go:test) FILTERED=$(printf '%s\n' "$OUTPUT" | grep -E '(^ok|^FAIL|^---|^panic|PASS|SKIP)') ;;
  cargo:test) FILTERED=$(printf '%s\n' "$OUTPUT" | grep -E '(^test |test result|^running|^failures|FAILED|^error)') ;;
  cargo:build) FILTERED=$(printf '%s\n' "$OUTPUT" | grep -E '(^error|^warning|Compiling|Finished|could not compile)') ;;
  docker:build) FILTERED=$(printf '%s\n' "$OUTPUT" | grep -E '(^Step |^Successfully|^ERROR|FINISHED|CACHED|error:)') ;;
  make:*|make:test) FILTERED=$(printf '%s\n' "$OUTPUT" | grep -E '(^make|Error|error:|warning:|PASS|FAIL|Nothing to be done|is up to date)') ;;
  mvn:test|mvn:install) FILTERED=$(printf '%s\n' "$OUTPUT" | grep -E '(BUILD SUCCESS|BUILD FAILURE|Tests run:|^\[ERROR\]|^\[WARNING\])') ;;
  gradle:test|gradle:build) FILTERED=$(printf '%s\n' "$OUTPUT" | grep -E '(BUILD SUCCESSFUL|BUILD FAILED|tests completed|FAILURE:|> Task)') ;;
  dotnet:test) FILTERED=$(printf '%s\n' "$OUTPUT" | grep -E '(Passed!|Failed!|Total tests|error |warning )') ;;
  dotnet:build) FILTERED=$(printf '%s\n' "$OUTPUT" | grep -E '(Build succeeded|Build FAILED|error |warning )') ;;
  swift:test) FILTERED=$(printf '%s\n' "$OUTPUT" | grep -E '(Test Case|Test Suite|passed|failed|Executed|error:)') ;;
  swift:build) FILTERED=$(printf '%s\n' "$OUTPUT" | grep -E '(Build complete|error:|warning:|Compiling|Linking)') ;;
  tsc:*) FILTERED=$(printf '%s\n' "$OUTPUT" | grep -E '(error TS|: error|Found [0-9]+ error)') ;;
  *) printf '%s\n' "$OUTPUT"; exit $EXIT_CODE ;;
esac
if [ -z "$FILTERED" ]; then printf '%s\n' "$OUTPUT"; else printf '%s\n' "$FILTERED"; fi
exit $EXIT_CODE
SAVEREOF
chmod +x "$HOOKS_DIR/token-saver.sh"
echo "    Created token-saver.sh"

# -- Clean up legacy hooks ----------------------------------------------------
for legacy_file in command-validator.js output-filter.js; do
  if [ -f "$HOOKS_DIR/$legacy_file" ]; then
    rm -f "$HOOKS_DIR/$legacy_file"
    echo "    Removed legacy $legacy_file"
  fi
done

# -- Patch settings.json ------------------------------------------------------
if [ -f "$SETTINGS" ]; then
  SETTINGS_ESCAPED=$(printf '%s' "$SETTINGS" | sed "s/'/\\\\'/g")
  node -e "
const fs = require('fs');
const settingsPath = '${SETTINGS_ESCAPED}';
const s = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));

// Add permission
const perm = 'Bash(~/.claude/hooks/token-saver.sh *)';
if (!s.permissions) s.permissions = {};
if (!s.permissions.allow) s.permissions.allow = [];
if (!s.permissions.allow.includes(perm)) {
  s.permissions.allow.push(perm);
}

// Remove legacy Bash hooks, add bash-interceptor.js
if (!s.hooks) s.hooks = {};
if (!s.hooks.PreToolUse) s.hooks.PreToolUse = [];
let bashEntry = s.hooks.PreToolUse.find(h => h.matcher === 'Bash');
if (!bashEntry) {
  bashEntry = { matcher: 'Bash', hooks: [] };
  s.hooks.PreToolUse.push(bashEntry);
}
if (!bashEntry.hooks) bashEntry.hooks = [];
bashEntry.hooks = bashEntry.hooks.filter(h =>
  !h.command?.includes('command-validator.js') &&
  !h.command?.includes('output-filter.js')
);
const interceptorCmd = 'node ~/.claude/hooks/bash-interceptor.js';
if (!bashEntry.hooks.some(h => h.command === interceptorCmd)) {
  bashEntry.hooks.unshift({ type: 'command', command: interceptorCmd });
}

fs.writeFileSync(settingsPath, JSON.stringify(s, null, 2) + '\n');
" 2>/dev/null && echo "    Patched settings.json" || echo "    Could not patch settings.json (update manually)"
fi

echo "    Done."
