#!/usr/bin/env bash
# FORGE Updater — Standalone terminal script
# Equivalent to /forge-update but runs outside Claude Code.
set -euo pipefail

# Colors (disabled if not a terminal)
if [ -t 1 ]; then
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    RED='\033[0;31m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    GREEN='' YELLOW='' BLUE='' RED='' BOLD='' NC=''
fi

info()  { printf '%b\n' "${BLUE}->${NC} $1"; }
ok()    { printf '%b\n' "${GREEN}ok${NC} $1"; }
warn()  { printf '%b\n' "${YELLOW}!${NC} $1"; }
error() { printf '%b\n' "${RED}x${NC} $1" >&2; }

CLAUDE_DIR="${HOME}/.claude"
TMPDIR="/tmp/forge-update-$(date +%Y%m%d-%H%M%S)"
INSTALL_PACK=""
PACK_ONLY=false
AUTO_YES=false

# ---- Parse arguments --------------------------------------------------------

while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes)
            AUTO_YES=true
            shift
            ;;
        --pack)
            INSTALL_PACK="${2:-}"
            shift 2
            ;;
        --only)
            PACK_ONLY=true
            shift
            ;;
        -h|--help)
            echo "Usage: bash update.sh [-y] [--pack business] [--only]"
            echo ""
            echo "  -y, --yes         Accept all prompts automatically"
            echo "  --pack business   Install/update the Business Pack"
            echo "  --only            Only update the pack, skip core skills"
            exit 0
            ;;
        *)
            error "Unknown argument: $1"
            exit 1
            ;;
    esac
done

# ---- Banner -----------------------------------------------------------------

echo ""
printf '%b\n' "${GREEN}FORGE${NC} -- Update"
echo ""

# ---- Pre-checks -------------------------------------------------------------

if [ ! -f "${CLAUDE_DIR}/skills/forge/SKILL.md" ]; then
    error "FORGE is not installed. Run install.sh first:"
    error "  git clone https://github.com/fwehrling/forge.git /tmp/forge && bash /tmp/forge/install.sh"
    exit 1
fi

OLD_VERSION="unknown"
if [ -f "${CLAUDE_DIR}/skills/forge/.forge-version" ]; then
    OLD_VERSION="$(cat "${CLAUDE_DIR}/skills/forge/.forge-version" | tr -d '[:space:]')"
fi
info "Current version: v${OLD_VERSION}"

# ---- Clone repo --------------------------------------------------------------

info "Fetching latest version..."
rm -rf "$TMPDIR"
git clone --depth 1 --quiet https://github.com/fwehrling/forge.git "$TMPDIR"

NEW_VERSION="unknown"
if [ -f "${TMPDIR}/VERSION" ]; then
    NEW_VERSION="$(cat "${TMPDIR}/VERSION" | tr -d '[:space:]')"
fi

SAME_VERSION=false
if [ "$OLD_VERSION" = "$NEW_VERSION" ]; then
    SAME_VERSION=true
fi

# ---- Compare skills ----------------------------------------------------------

MODIFIED=0
NEW_SKILLS=0
MODIFIED_LIST=""

compare_skill() {
    local skill_name="$1"
    local source_dir="$2"
    local target_dir="${CLAUDE_DIR}/skills/${skill_name}"

    if [ ! -d "$target_dir" ]; then
        NEW_SKILLS=$((NEW_SKILLS + 1))
        MODIFIED_LIST="${MODIFIED_LIST}\n  ${GREEN}+ new${NC}  ${skill_name}"
        return
    fi

    # Compare only SKILL.md -- the single file that defines a skill
    local src_skill="${source_dir}/SKILL.md"
    local dst_skill="${target_dir}/SKILL.md"

    if [ -f "$src_skill" ] && [ -f "$dst_skill" ]; then
        if ! diff -q "$src_skill" "$dst_skill" &>/dev/null; then
            MODIFIED=$((MODIFIED + 1))
            MODIFIED_LIST="${MODIFIED_LIST}\n  ${YELLOW}~ mod${NC}  ${skill_name}"
        fi
    elif [ -f "$src_skill" ] && [ ! -f "$dst_skill" ]; then
        NEW_SKILLS=$((NEW_SKILLS + 1))
        MODIFIED_LIST="${MODIFIED_LIST}\n  ${GREEN}+ new${NC}  ${skill_name}"
    fi
}

if [ "$PACK_ONLY" = false ]; then
    for dir in "${TMPDIR}/skills/"*/; do
        [ -d "$dir" ] || continue
        skill_name="$(basename "$dir")"
        compare_skill "$skill_name" "$dir"
    done
fi

# Compare pack skills if requested or already installed
PACK_MODIFIED=0
PACK_LIST=""
if [ -n "$INSTALL_PACK" ] && [ -d "${TMPDIR}/packs/${INSTALL_PACK}" ]; then
    for dir in "${TMPDIR}/packs/${INSTALL_PACK}/"forge-*/; do
        [ -d "$dir" ] || continue
        skill_name="$(basename "$dir")"
        local_dir="${CLAUDE_DIR}/skills/${skill_name}"
        if [ ! -d "$local_dir" ]; then
            PACK_MODIFIED=$((PACK_MODIFIED + 1))
            PACK_LIST="${PACK_LIST}\n  ${GREEN}+ new${NC}  ${skill_name}"
        elif [ -f "$dir/SKILL.md" ] && [ -f "$local_dir/SKILL.md" ]; then
            if ! diff -q "$dir/SKILL.md" "$local_dir/SKILL.md" &>/dev/null; then
                PACK_MODIFIED=$((PACK_MODIFIED + 1))
                PACK_LIST="${PACK_LIST}\n  ${YELLOW}~ mod${NC}  ${skill_name}"
            fi
        fi
    done
elif [ -d "${TMPDIR}/packs/business" ]; then
    # Auto-update previously installed business pack skills
    for dir in "${TMPDIR}/packs/business/"forge-*/; do
        [ -d "$dir" ] || continue
        skill_name="$(basename "$dir")"
        if [ -d "${CLAUDE_DIR}/skills/${skill_name}" ]; then
            if [ -f "$dir/SKILL.md" ] && [ -f "${CLAUDE_DIR}/skills/${skill_name}/SKILL.md" ]; then
                if ! diff -q "$dir/SKILL.md" "${CLAUDE_DIR}/skills/${skill_name}/SKILL.md" &>/dev/null; then
                    PACK_MODIFIED=$((PACK_MODIFIED + 1))
                    PACK_LIST="${PACK_LIST}\n  ${YELLOW}~ mod${NC}  ${skill_name} (business)"
                fi
            fi
        fi
    done
fi

# Display comparison results
TOTAL_CHANGES=$((MODIFIED + NEW_SKILLS + PACK_MODIFIED))
if [ "$SAME_VERSION" = true ] && [ "$TOTAL_CHANGES" -eq 0 ]; then
    ok "Already up to date (v${NEW_VERSION}) -- nothing to do"
    rm -rf "$TMPDIR"
    echo ""
    exit 0
fi

if [ "$SAME_VERSION" = true ] && [ "$TOTAL_CHANGES" -gt 0 ]; then
    info "Version is v${NEW_VERSION} but some files differ:"
elif [ "$SAME_VERSION" = false ]; then
    info "Updating v${OLD_VERSION} -> v${NEW_VERSION}"
fi

if [ "$TOTAL_CHANGES" -gt 0 ]; then
    [ -n "$MODIFIED_LIST" ] && printf '%b\n' "$MODIFIED_LIST"
    [ -n "$PACK_LIST" ] && printf '%b\n' "$PACK_LIST"
    echo ""
fi

# ---- Copy core skills --------------------------------------------------------

if [ "$PACK_ONLY" = false ]; then
    info "Updating core skills..."

    for dir in "${TMPDIR}/skills/"*/; do
        [ -d "$dir" ] || continue
        skill_name="$(basename "$dir")"
        \cp -rf "$dir" "${CLAUDE_DIR}/skills/${skill_name}"
    done

    # Remove deprecated skills
    REMOVED_SKILLS="forge-deploy"
    for skill in $REMOVED_SKILLS; do
        if [ -d "${CLAUDE_DIR}/skills/${skill}" ]; then
            rm -rf "${CLAUDE_DIR}/skills/${skill}"
            warn "Removed deprecated skill: ${skill}"
        fi
    done

    ok "Core skills updated"
fi

# ---- Copy pack skills --------------------------------------------------------

if [ -n "$INSTALL_PACK" ] && [ -d "${TMPDIR}/packs/${INSTALL_PACK}" ]; then
    info "Installing ${INSTALL_PACK} pack..."
    for dir in "${TMPDIR}/packs/${INSTALL_PACK}/"forge-*/; do
        [ -d "$dir" ] || continue
        skill_name="$(basename "$dir")"
        \cp -rf "$dir" "${CLAUDE_DIR}/skills/${skill_name}"
    done
    ok "Business pack installed"
elif [ -d "${TMPDIR}/packs/business" ]; then
    # Auto-update previously installed business pack skills
    local_updated=0
    for dir in "${TMPDIR}/packs/business/"forge-*/; do
        [ -d "$dir" ] || continue
        skill_name="$(basename "$dir")"
        if [ -d "${CLAUDE_DIR}/skills/${skill_name}" ]; then
            \cp -rf "$dir" "${CLAUDE_DIR}/skills/${skill_name}"
            local_updated=$((local_updated + 1))
        fi
    done
    if [ "$local_updated" -gt 0 ]; then
        ok "Business pack updated (${local_updated} skills)"
    fi
fi

# ---- Update version and cache ------------------------------------------------

info "Updating version and hooks..."

\cp -f "${TMPDIR}/VERSION" "${CLAUDE_DIR}/skills/forge/.forge-version"
rm -f "${CLAUDE_DIR}/skills/forge/.forge-update-cache"

# ---- Update hooks ------------------------------------------------------------

if [ -f "${CLAUDE_DIR}/skills/forge/scripts/forge-hooks-setup.sh" ]; then
    if FORGE_AUTO="$AUTO_YES" bash "${CLAUDE_DIR}/skills/forge/scripts/forge-hooks-setup.sh"; then
        ok "Hooks updated"
    else
        warn "Hook setup failed (non-blocking)"
    fi
fi

# ---- Update CLAUDE.md --------------------------------------------------------

if [ -f "${TMPDIR}/scripts/inject-claude-md.sh" ]; then
    FORGE_YES="$AUTO_YES" bash "${TMPDIR}/scripts/inject-claude-md.sh"
fi

# ---- Cleanup -----------------------------------------------------------------

rm -rf "$TMPDIR"

# ---- Summary -----------------------------------------------------------------

SKILL_COUNT=$(find "${CLAUDE_DIR}/skills" -maxdepth 2 -name "SKILL.md" | wc -l | tr -d ' ')

echo ""
printf '%b\n' "${GREEN}---------------------------------------------${NC}"
printf '%b\n' "${GREEN}  FORGE updated successfully${NC}"
printf '%b\n' "${GREEN}---------------------------------------------${NC}"
echo ""
if [ "$SAME_VERSION" = true ]; then
    echo "  Version : v${NEW_VERSION} (synced)"
else
    echo "  Version : v${OLD_VERSION} -> v${NEW_VERSION}"
fi
echo "  Skills  : ${SKILL_COUNT} installed"
if [ "$TOTAL_CHANGES" -gt 0 ]; then
    echo "  Changed : ${TOTAL_CHANGES} (${MODIFIED} core, ${NEW_SKILLS} new, ${PACK_MODIFIED} pack)"
else
    echo "  Changed : 0"
fi

# Suggest business pack if not installed
HAS_BUSINESS=false
for bp_skill in forge-marketing forge-copywriting forge-seo forge-geo forge-legal forge-security-pro forge-business-strategy forge-strategy-panel; do
    if [ -d "${CLAUDE_DIR}/skills/${bp_skill}" ]; then
        HAS_BUSINESS=true
        break
    fi
done

if [ "$HAS_BUSINESS" = false ] && [ -z "$INSTALL_PACK" ]; then
    echo ""
    printf '%b\n' "  ${YELLOW}Tip:${NC} Business Pack available (marketing, SEO, legal, security, strategy)."
    echo "        Run: bash update.sh --pack business"
fi

echo ""
