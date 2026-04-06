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

## Token Efficiency (RTK)
- Hook Bash (auto): all Bash commands transparently rewritten via RTK. No action needed.
- Hook natif (Read/Grep/Glob): active above thresholds (80L / 50 results / 30 entries). When blocked, use the compressed content in the denial reason directly.
- Only compresses source files (.ts .js .py .go .rs etc.) -- shell/config files pass through.
- \`rtk gain\` -- view token savings analytics
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
