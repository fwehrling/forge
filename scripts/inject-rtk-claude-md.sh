#!/usr/bin/env bash
# inject-rtk-claude-md.sh - Injects the FORGE:RTK section into ~/.claude/CLAUDE.md
# Uses <!-- FORGE:RTK:BEGIN --> / <!-- FORGE:RTK:END --> markers (non-destructive)
# Safe to run multiple times (idempotent)

set -euo pipefail

CLAUDE_MD="${HOME}/.claude/CLAUDE.md"
MARKER_BEGIN="<!-- FORGE:RTK:BEGIN -->"
MARKER_END="<!-- FORGE:RTK:END -->"

RTK_BLOCK="${MARKER_BEGIN}
@RTK.md

## Token Efficiency (RTK) -- CRITICAL RULES

### Bash hook (transparent)
All Bash commands are automatically rewritten via RTK. No action needed.

### Native tool hook (Read/Grep/Glob) -- MANDATORY BEHAVIOR
RTK intercepts Read, Grep, and Glob calls above thresholds (80L / 50L / 30 entries) and returns compressed content via a hook denial.

**IMPORTANT: The word \"deny\" is a PROTOCOL ARTIFACT, not an access refusal.** RTK uses the deny mechanism as a delivery channel because the Claude Code hook protocol has no \"allow + replace content\" option. The compressed content IS the file content.

**When you see \`[RTK:Read:OK]\`, \`[RTK:Grep:OK]\`, or \`[RTK:Glob:OK]\` in a tool denial:**
1. The \`permissionDecisionReason\` contains the COMPLETE, USABLE, compressed result
2. This IS the tool result. It is semantically complete. Nothing is missing.
3. **Treat RTK denials as SUCCESSFUL tool calls with optimized output**

**NEVER do any of the following after an RTK denial:**
- Re-read the file with \`offset\`/\`limit\` to \"get the real content\"
- Fall back to Bash with \`cat\`, \`head\`, \`tail\`, or \`sed\`
- Try an alternative approach to \"work around\" the denial
- Tell the user that the content was truncated or unavailable
- Apologize for not being able to read the file

**The denial IS the success.** Use the compressed content directly and continue your task. Bypassing RTK wastes tokens and frustrates the user.

### Notes
- Only compresses source files (.ts .js .py .go .rs etc.) -- shell/config files pass through.
- \`rtk gain\` -- token savings analytics
${MARKER_END}"

# Case 1: file does not exist
if [ ! -f "${CLAUDE_MD}" ]; then
    mkdir -p "$(dirname "${CLAUDE_MD}")"
    printf '%s\n' "${RTK_BLOCK}" > "${CLAUDE_MD}"
    echo "Created ${CLAUDE_MD} with RTK section"
    exit 0
fi

# Case 2: markers already present -> silent replace
if grep -q "${MARKER_BEGIN}" "${CLAUDE_MD}" 2>/dev/null; then
    BEFORE="$(sed -n "1,/^${MARKER_BEGIN//\//\\/}$/{/^${MARKER_BEGIN//\//\\/}$/d;p;}" "${CLAUDE_MD}")"
    AFTER="$(sed -n "/^${MARKER_END//\//\\/}$/,\${/^${MARKER_END//\//\\/}$/d;p;}" "${CLAUDE_MD}")"
    { printf '%s\n' "${BEFORE}"; printf '%s\n' "${RTK_BLOCK}"; printf '%s' "${AFTER}"; } > "${CLAUDE_MD}"
    echo "Updated existing RTK section in ${CLAUDE_MD}"
    exit 0
fi

# Case 3: no markers -> append
printf '\n%s\n' "${RTK_BLOCK}" >> "${CLAUDE_MD}"
echo "Added RTK section to ${CLAUDE_MD}"
