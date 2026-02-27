#!/usr/bin/env bash
# FORGE — Inject/update FORGE section in ~/.claude/CLAUDE.md
# Used by install.sh and /forge-update
set -euo pipefail

# Colors (disabled if not a terminal)
if [ -t 1 ]; then
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    GREEN='' YELLOW='' BLUE='' NC=''
fi

info()  { echo -e "${BLUE}→${NC} $1"; }
ok()    { echo -e "${GREEN}✓${NC} $1"; }
warn()  { echo -e "${YELLOW}!${NC} $1"; }

CLAUDE_MD="${HOME}/.claude/CLAUDE.md"
MARKER_BEGIN="<!-- FORGE:BEGIN -->"
MARKER_END="<!-- FORGE:END -->"

# Resolve template path (relative to this script)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Allow override via argument, otherwise look in repo structure
if [ -n "${1:-}" ] && [ -f "$1" ]; then
    TEMPLATE="$1"
elif [ -f "${SCRIPT_DIR}/../templates/claude-md-forge-section.md" ]; then
    TEMPLATE="${SCRIPT_DIR}/../templates/claude-md-forge-section.md"
elif [ -f "${HOME}/.claude/skills/forge/templates/claude-md-forge-section.md" ]; then
    TEMPLATE="${HOME}/.claude/skills/forge/templates/claude-md-forge-section.md"
else
    warn "FORGE template not found — skipping CLAUDE.md injection."
    exit 0
fi

TEMPLATE_CONTENT="$(cat "$TEMPLATE")"
FORGE_BLOCK="${MARKER_BEGIN}
${TEMPLATE_CONTENT}
${MARKER_END}"

# ─── Backup helper ────────────────────────────────────────────────────────────

backup_claude_md() {
    if [ -f "$CLAUDE_MD" ]; then
        local backup="${CLAUDE_MD}.backup-$(date +%Y%m%d-%H%M%S)"
        cp "$CLAUDE_MD" "$backup"
        info "Backup saved: ${backup}"
    fi
}

# ─── Case 1: File does not exist ─────────────────────────────────────────────

if [ ! -f "$CLAUDE_MD" ]; then
    mkdir -p "$(dirname "$CLAUDE_MD")"
    info "~/.claude/CLAUDE.md does not exist."
    echo ""
    echo "The following FORGE configuration will be added:"
    echo "---"
    echo "$TEMPLATE_CONTENT"
    echo "---"
    echo ""
    read -p "$(echo -e "${YELLOW}?${NC}") Create ~/.claude/CLAUDE.md with FORGE section? [y/N] " answer
    if [[ "${answer}" =~ ^[Yy]$ ]]; then
        printf '%s\n' "$FORGE_BLOCK" > "$CLAUDE_MD"
        ok "Created ~/.claude/CLAUDE.md with FORGE section"
    else
        info "Skipped. You can run this again later."
    fi
    exit 0
fi

# ─── Case 2: Markers already present → replace silently ──────────────────────

if grep -q "$MARKER_BEGIN" "$CLAUDE_MD" && grep -q "$MARKER_END" "$CLAUDE_MD"; then
    backup_claude_md

    # Extract before, after, and replace the FORGE block
    BEFORE="$(sed -n "1,/^${MARKER_BEGIN}$/{ /^${MARKER_BEGIN}$/d; p; }" "$CLAUDE_MD")"
    AFTER="$(sed -n "/^${MARKER_END}$/,\${ /^${MARKER_END}$/d; p; }" "$CLAUDE_MD")"

    {
        printf '%s\n' "$BEFORE"
        printf '%s\n' "$FORGE_BLOCK"
        printf '%s' "$AFTER"
    } > "$CLAUDE_MD"

    ok "FORGE section updated in ~/.claude/CLAUDE.md"
    exit 0
fi

# ─── Case 3: No markers → ask before appending ───────────────────────────────

echo ""
info "~/.claude/CLAUDE.md exists but has no FORGE section markers."
echo ""
echo "The following will be appended to your CLAUDE.md:"
echo "---"
echo "$TEMPLATE_CONTENT"
echo "---"
echo ""
read -p "$(echo -e "${YELLOW}?${NC}") Add FORGE section to ~/.claude/CLAUDE.md? [y/N] " answer
if [[ "${answer}" =~ ^[Yy]$ ]]; then
    backup_claude_md
    printf '\n%s\n' "$FORGE_BLOCK" >> "$CLAUDE_MD"
    ok "FORGE section added to ~/.claude/CLAUDE.md"
else
    info "Skipped. You can run this again later."
fi
