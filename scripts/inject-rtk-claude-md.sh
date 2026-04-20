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

### Bash hook (transparent)
All Bash commands are automatically rewritten via RTK. No action needed -- 60-90% token savings on dev operations (git, ls, grep, etc.).

### Notes
- Native Read/Grep/Glob compression was removed: the Claude Code hook protocol has no \"allow + replace content\" primitive, so the deny-based delivery channel was bypassed in practice and cost more tokens than it saved.
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
