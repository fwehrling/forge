#!/usr/bin/env bash
# FORGE Hooks — Complete setup script
# Installs ALL FORGE hooks into ~/.claude/hooks/ and patches ~/.claude/settings.json.
#
# Hooks installed:
#   1. command-validator.js   — PreToolUse[Bash]    — Blocks dangerous commands
#   2. output-filter.js       — PreToolUse[Bash]    — Rewrites verbose commands through token-saver
#   3. token-saver.sh         — Execution script     — Filters verbose output to save tokens
#   4. forge-auto-router.js   — UserPromptSubmit     — Routes requests through /forge router
#   5. forge-update-check.sh  — SessionStart          — Notifies of FORGE updates (1x/24h)
#   6. forge-memory-sync.sh   — Stop                  — Auto-syncs vector memory on session end
#   7. PreToolUse[Skill]      — Inline in settings    — Displays FORGE notification on skill use
#
# Idempotent: safe to run multiple times.
# Called by: forge-init.sh, install.sh
#
# Usage: bash forge-hooks-setup.sh

set -euo pipefail

HOOKS_DIR="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"

echo "  🔨 FORGE Hooks — Installing complete hook infrastructure..."
mkdir -p "$HOOKS_DIR"

# ═══════════════════════════════════════════════════════════════════════════════
# 1. command-validator.js — PreToolUse[Bash] — Security guard
# ═══════════════════════════════════════════════════════════════════════════════
if [ ! -f "$HOOKS_DIR/command-validator.js" ]; then
  cat > "$HOOKS_DIR/command-validator.js" << 'VALIDATOREOF'
/**
 * Command Validator Hook for Claude Code
 *
 * PreToolUse hook for Bash tool.
 * Reads JSON from stdin (synchronous) per the Claude Code hooks protocol.
 * Exit 0 = allow, non-zero = block.
 */

const fs = require('fs');

const BLOCKED_PATTERNS = [
  // Destructive file operations
  /rm\s+(-rf?|--recursive)\s+[\/~]/i,
  /rm\s+-rf?\s+\//i,
  /rm\s+-rf?\s+~/i,
  /rm\s+-rf?\s+\.\.\//i,
  /rmdir\s+--ignore-fail-on-non-empty\s+[\/~]/i,

  // System destruction
  /sudo\s+rm\s+-rf?\s+\//i,
  />\s*\/dev\/sd[a-z]/i,
  /dd\s+if=.*of=\/dev\/sd/i,
  /mkfs\.\w+\s+\/dev\/sd/i,

  // Permission disasters
  /chmod\s+(-R\s+)?777\s+\//i,
  /chown\s+-R\s+.*\s+\//i,

  // Fork bombs and system overload
  /:\(\)\{\s*:\|:&\s*\};:/,
  /while\s+true;\s*do/i,

  // Dangerous downloads
  /curl.*\|\s*(sudo\s+)?bash/i,
  /wget.*\|\s*(sudo\s+)?bash/i,

  // Environment destruction
  /unset\s+(PATH|HOME|USER)/i,
  /export\s+PATH\s*=\s*$/i,

  // Database destruction
  /DROP\s+DATABASE/i,
  /DROP\s+TABLE\s+\*/i,
  /TRUNCATE\s+TABLE/i,
  /DELETE\s+FROM\s+\w+\s*;?\s*$/i,

  // Git disasters
  /git\s+push\s+--force\s+origin\s+main/i,
  /git\s+push\s+-f\s+origin\s+main/i,
  /git\s+reset\s+--hard\s+HEAD~\d{2,}/i,

  // SSH/Network dangers
  /ssh.*rm\s+-rf/i,
];

function validateCommand(command) {
  const cmd = command.trim();
  for (const pattern of BLOCKED_PATTERNS) {
    if (pattern.test(cmd)) {
      return { allowed: false, reason: `Commande dangereuse bloquee : ${pattern}` };
    }
  }
  return { allowed: true };
}

if (require.main === module) {
  try {
    const input = fs.readFileSync(0, 'utf8');
    const data = JSON.parse(input);
    const command = data?.tool_input?.command || '';

    if (!command) {
      process.exit(0);
    }

    const result = validateCommand(command);
    if (!result.allowed) {
      process.stderr.write(result.reason + '\n');
      process.exit(2);
    }
    process.exit(0);
  } catch {
    process.exit(0);
  }
}

module.exports = { validateCommand, BLOCKED_PATTERNS };
VALIDATOREOF
  echo "    ✅ Created command-validator.js"
else
  echo "    ⏭  command-validator.js already exists"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# 2. output-filter.js — PreToolUse[Bash] — Token optimization
# ═══════════════════════════════════════════════════════════════════════════════
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

const HOME = process.env.HOME || process.env.USERPROFILE || '/tmp';
const TOKEN_SAVER = path.join(HOME, '.claude', 'hooks', 'token-saver.sh');

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

  // Special case: "pnpm run test" -> match "pnpm run" but only if 3rd word starts with "test"
  if (key2 === 'pnpm run' && words.length >= 3 && !words[2].startsWith('test')) {
    return false;
  }

  // Special case: "python -m pytest" -> match "python -m" but only if 3rd word is "pytest"
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
  } catch (err) {
    // Fail open -- passthrough on any error
    // Log to stderr for debugging (won't affect Claude output)
    process.stderr.write(`[token-saver] hook error: ${err.message}\n`);
    process.exit(0);
  }
}

module.exports = { shouldFilter, FILTERED_COMMANDS };
FILTEREOF
  echo "    ✅ Created output-filter.js"
else
  echo "    ⏭  output-filter.js already exists"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# 3. token-saver.sh — Execution script for output filtering
# ═══════════════════════════════════════════════════════════════════════════════
if [ ! -f "$HOOKS_DIR/token-saver.sh" ]; then
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
    FILTERED=$(printf '%s\n' "$OUTPUT" | awk '/^commit [0-9a-f]+/{print;t=1;next} /^(Author|Date):/{next} /^$/{next} t&&/^    /{sub(/^    /,"  ");print;t=0;next}')
    ;;
  npm:test|npx:jest|npx:vitest|pnpm:test|pnpm:run|yarn:test|bun:test)
    # Keep PASS/FAIL per file, errors, and summary -- drop individual test lines
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
    # Keep per-file results + errors + summary -- drop individual test lines
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
    # Unknown command -- passthrough
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
  if [ -x "$HOOKS_DIR/token-saver.sh" ]; then
    echo "    ✅ Created token-saver.sh"
  else
    echo "    ⚠️  Created token-saver.sh but could not make it executable" >&2
  fi
else
  echo "    ⏭  token-saver.sh already exists"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# 4. forge-auto-router.js — UserPromptSubmit — Intelligent routing
# ═══════════════════════════════════════════════════════════════════════════════
if [ ! -f "$HOOKS_DIR/forge-auto-router.js" ]; then
  cat > "$HOOKS_DIR/forge-auto-router.js" << 'ROUTEREOF'
#!/usr/bin/env node

/**
 * forge-auto-router.js -- UserPromptSubmit hook
 *
 * Injects additionalContext to route every user request through /forge
 * (the intelligent router) unless the request is a skip case.
 *
 * Skip cases:
 *  - Explicit skill invocation (/something)
 *  - Simple confirmations (oui, non, ok, etc.)
 *  - Greetings
 *  - Very short follow-ups without action keywords
 */

const input = [];
process.stdin.on('data', (d) => input.push(d));
process.stdin.on('end', () => {
  try {
    const data = JSON.parse(Buffer.concat(input).toString());
    const prompt = (data.prompt || '').trim();

    // Skip: explicit skill invocations (user already typed /something)
    if (prompt.startsWith('/')) {
      return;
    }

    // Skip: simple confirmations, greetings, short acknowledgments
    const skipExact = /^(oui|non|yes|no|ok|d'accord|merci|thanks|thank you|bonjour|hello|salut|hey|stop|cancel|annule|c'est bon|parfait|super|go|continue|next)$/i;
    if (skipExact.test(prompt)) {
      return;
    }

    // Skip: very short prompts (< 15 chars) unless they contain action keywords
    const actionKeywords = /\b(build|fix|deploy|test|plan|review|audit|create|implement|code|develop|analyse|analyze|strateg|market|seo|security|legal|design|architect|stories|sprint|resume|status|bug|feature|refactor|optimize|debug|patch|hotfix|migrate|upgrade|update|release|ship|publish|scale|setup|config|configure|install|remove|delete|add|change|move|rename|split|merge|rewrite|cleanup|lint|format|benchmark|profile|monitor|pipeline|ci|cd|docker|container|backup|restore|schema|endpoint|route|middleware|webhook|cron|service|widget|module|component|plugin|performance|cache|index|query|database|api|auth|login|session|token|email|notification|invoice|payment|stripe|booking|recipe|blog|chat|calendar|social|umami|analytics|tracking|pdf|export|import|upload|download|image|style|css|responsive|mobile|accessibility|a11y|wcag|i18n|prd|adr|spec|story|acceptance|criteria|coverage|lance|fais|construi|ajoute|supprime|modifie|change|renomme|deplace|nettoie|migre|mets a jour|met a jour|pousse|envoie|genere|cree|ecris|configure|installe|demarre|arrete|relance|redemarre|branche|merge|rebase|cherry.pick|tag|release|ship|deploie|teste|verifie|corrige|repare|resou[ds]|investigue|diagnostique|analyse|optimise|ameliore|securise|documente|refactorise|restructure|implemente|developpe|concoi[st]|planifie|prepare|valide|certifie|audite|revise|monitore|profile|benchmark|marche pas|fonctionne pas|casse|plante|erreur|probleme|souci|blocage|regression|lent|timeout|crash|echoue|rate|impossible|manque|absent|perdu|disparu|incorrect|mauvais|faux|doublon|duplique|oublie|ignore|affiche pas|charge pas|repond pas|enregistre pas|sauvegarde pas|supprime pas|envoie pas|recoit pas|connecte pas|synchronise pas|apparait pas|disparait|toujours|encore|devrait|pourquoi|comment)\b/i;
    if (prompt.length < 15 && !actionKeywords.test(prompt)) {
      return;
    }

    // Inject routing context for everything else
    console.log(JSON.stringify({
      additionalContext: [
        "[FORGE AUTO-ROUTER] Le routage automatique /forge est actif.",
        "INSTRUCTION: Avant de traiter cette requete, invoque le skill /forge",
        "(via Skill tool: skill \"forge\", args: le message complet de l'utilisateur).",
        "/forge classifiera l'intent et deleguera au bon skill FORGE ou agent custom.",
        "EXCEPTIONS -- traite directement SANS passer par /forge UNIQUEMENT si la requete est :",
        "- Une question simple sur le code (\"que fait cette fonction?\", \"montre-moi ce fichier\")",
        "- Une operation git (commit, push, branch, diff, log)",
        "- Une lecture/exploration de fichier",
        "- Un suivi conversationnel SANS action implicite (\"merci\", \"je comprends\", questions de clarification sur une reponse precedente)",
        "- Une demande de memoire/rappel (\"souviens-toi\", \"remember\")",
        "ATTENTION: Les cas suivants NE SONT PAS des exceptions et DOIVENT passer par /forge :",
        "- Signalement de bug ou comportement inattendu (\"ca marche pas\", \"c'est toujours la\", \"ca devrait pas\")",
        "- Demande implicite de correction (\"j'ai desactive X mais Y est toujours present\")",
        "- Description d'un probleme a resoudre, meme formulee comme un constat",
        "- Toute requete qui implique une modification de code, meme indirectement",
        "Dans le doute, passe par /forge."
      ].join(" ")
    }));
  } catch (e) {
    // On error, pass through silently -- don't block the user
  }
});
ROUTEREOF
  echo "    ✅ Created forge-auto-router.js"
else
  echo "    ⏭  forge-auto-router.js already exists"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# 5. forge-update-check.sh — SessionStart — Update notifications
# ═══════════════════════════════════════════════════════════════════════════════
if [ ! -f "$HOOKS_DIR/forge-update-check.sh" ]; then
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
        # Cache still fresh -- print cached notification if any
        cached_msg=$(tail -n +2 "$CACHE_FILE" 2>/dev/null || true)
        if [ -n "$cached_msg" ]; then
            echo "$cached_msg"
        fi
        exit 0
    fi
fi

# Fetch remote version (timeout 3s)
remote_version=$(curl -s --max-time 3 "$REMOTE_URL" 2>/dev/null | tr -d '[:space:]') || true

# Validate: must be non-empty and look like semver (e.g. 1.2.3)
if [ -z "$remote_version" ] || ! echo "$remote_version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+'; then
    exit 0
fi

local_version=$(tr -d '[:space:]' < "$LOCAL_VERSION_FILE")

# Compare versions
now=$(date +%s)
if [ "$local_version" != "$remote_version" ]; then
    msg="FORGE update available (v${local_version} -> v${remote_version}). Run /forge-update to update."
    # Write cache with notification
    printf '%s\n%s\n' "$now" "$msg" > "$CACHE_FILE"
    echo "$msg"
else
    # Write cache without notification (versions match)
    printf '%s\n' "$now" > "$CACHE_FILE"
fi

exit 0
UPDATEEOF
  chmod +x "$HOOKS_DIR/forge-update-check.sh"
  echo "    ✅ Created forge-update-check.sh"
else
  echo "    ⏭  forge-update-check.sh already exists"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# 6. forge-memory-sync.sh — Stop — Memory persistence
# ═══════════════════════════════════════════════════════════════════════════════
if [ ! -f "$HOOKS_DIR/forge-memory-sync.sh" ]; then
  cat > "$HOOKS_DIR/forge-memory-sync.sh" << 'MEMORYEOF'
#!/usr/bin/env bash
# FORGE Memory -- Auto-sync hook for Claude Code Stop event.
# Detects if the current project uses FORGE and:
#   1. Consolidates session logs into MEMORY.md
#   2. Syncs the vector memory index
# Non-blocking, silent -- always exits 0.

(
  # Find project root by walking up from CWD
  dir="$PWD"
  while [ "$dir" != "/" ]; do
    if [ -d "$dir/.forge/memory" ]; then
      cd "$dir" || break
      # Consolidate session logs into MEMORY.md first
      forge-memory consolidate 2>/dev/null
      # Then sync the vector index
      forge-memory sync 2>/dev/null
      break
    fi
    dir="$(dirname "$dir")"
  done
) &>/dev/null &

exit 0
MEMORYEOF
  chmod +x "$HOOKS_DIR/forge-memory-sync.sh"
  echo "    ✅ Created forge-memory-sync.sh"
else
  echo "    ⏭  forge-memory-sync.sh already exists"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# 7. Patch settings.json — Register ALL hooks + permissions
# ═══════════════════════════════════════════════════════════════════════════════
echo "  📝 Patching settings.json..."

# Create settings.json if it doesn't exist
if [ ! -f "$SETTINGS" ]; then
  echo '{}' > "$SETTINGS"
fi

SETTINGS_ESCAPED=$(printf '%s' "$SETTINGS" | sed "s/'/\\\\'/g")
node -e "
const fs = require('fs');
const settingsPath = '${SETTINGS_ESCAPED}';
const s = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));

// ── Permissions ──────────────────────────────────────────────────────────────
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

// ── Hooks ────────────────────────────────────────────────────────────────────
if (!s.hooks) s.hooks = {};

// Helper: ensure a hook entry exists for event+matcher, return the hooks array
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

// PreToolUse[Bash] — command-validator.js (security, must be FIRST)
const bashHooks = ensureHookEntry('PreToolUse', 'Bash');
const validatorCmd = 'node ~/.claude/hooks/command-validator.js';
if (!bashHooks.some(h => h.command === validatorCmd)) {
  bashHooks.unshift({ type: 'command', command: validatorCmd });
}

// PreToolUse[Bash] — output-filter.js (token optimization)
addCommandHook('PreToolUse', 'Bash', 'node ~/.claude/hooks/output-filter.js');

// PreToolUse[Skill] — FORGE notification
const skillNotifyCmd = 'jq -r \\'.tool_input.skill // \"\"\\' | { read -r skill; if echo \"\$skill\" | grep -qi \\'forge\\'; then echo \"{\\\\\"systemMessage\\\\\": \\\\\"FORGE active : \$skill\\\\\"}\"; fi; }';
addCommandHook('PreToolUse', 'Skill', skillNotifyCmd, { statusMessage: 'FORGE check...' });

// SessionStart — forge-update-check.sh
addCommandHook('SessionStart', '', 'bash ~/.claude/hooks/forge-update-check.sh');

// Stop — forge-memory-sync.sh
addCommandHook('Stop', '', 'bash ~/.claude/hooks/forge-memory-sync.sh');

// UserPromptSubmit — forge-auto-router.js
addCommandHook('UserPromptSubmit', '', 'node ~/.claude/hooks/forge-auto-router.js');

fs.writeFileSync(settingsPath, JSON.stringify(s, null, 2) + '\n');
" 2>/dev/null && echo "    ✅ Patched settings.json with all FORGE hooks" || echo "    ⚠️  Could not patch settings.json (update manually)"

echo ""
echo "  ✅ FORGE Hooks — Installation complete!"
echo "     6 hook scripts in ~/.claude/hooks/"
echo "     5 hook events in ~/.claude/settings.json"
echo "     (PreToolUse[Bash], PreToolUse[Skill], SessionStart, Stop, UserPromptSubmit)"
