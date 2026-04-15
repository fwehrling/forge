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
