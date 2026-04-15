#!/usr/bin/env bash
# FORGE Installer — Cross-platform (macOS, Linux, WSL)
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

info()  { printf '%b\n' "${BLUE}→${NC} $1"; }
ok()    { printf '%b\n' "${GREEN}✓${NC} $1"; }
warn()  { printf '%b\n' "${YELLOW}!${NC} $1"; }
error() { printf '%b\n' "${RED}✗${NC} $1" >&2; }
step()  { printf '\n%b\n' "${BOLD}[$1/$TOTAL_STEPS] $2${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"
TOTAL_STEPS=7
VECTOR_MEMORY_INSTALLED=false
RTK_INSTALLED=false
AUTO_YES="${FORGE_YES:-false}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes) AUTO_YES=true; shift ;;
        *) shift ;;
    esac
done

# ─── Banner ──────────────────────────────────────────────────────────────────

echo ""
printf '%b\n' "${GREEN}FORGE${NC} -- Framework for Orchestrated Resilient Generative Engineering"
echo ""

# ─── [1/6] Detect OS ────────────────────────────────────────────────────────

detect_os() {
    step 1 "Detecting OS..."

    case "$(uname -s)" in
        Darwin*)
            OS="macOS"
            ;;
        Linux*)
            if grep -qi microsoft /proc/version 2>/dev/null; then
                OS="WSL"
            else
                OS="Linux"
            fi
            ;;
        MINGW*|MSYS*|CYGWIN*)
            warn "Git Bash detected. FORGE requires a full POSIX environment."
            warn "Some features (vector memory, autonomous loops) will not work."
            warn "Recommended: use WSL instead — https://learn.microsoft.com/en-us/windows/wsl/install"
            echo ""
            if [ "$AUTO_YES" = true ]; then
                info "Auto-yes: continuing on Git Bash"
            else
                read -p "$(printf '%b' "${YELLOW}?${NC}") Continue anyway? [y/N] " answer
                if [[ ! "${answer}" =~ ^[Yy]$ ]]; then
                    info "Installation cancelled. Install WSL and try again."
                    exit 0
                fi
            fi
            OS="Git Bash"
            ;;
        *)
            error "Unsupported OS: $(uname -s)"
            error "FORGE supports macOS, Linux, and Windows (via WSL)."
            exit 1
            ;;
    esac

    ok "Detected OS: ${OS}"
}

# ─── [2/6] Install skills ───────────────────────────────────────────────────

FORGE_DIR="${HOME}/.forge"

verify_source() {
    if [ ! -d "${SCRIPT_DIR}/skills" ]; then
        error "Cannot find skills/ directory in ${SCRIPT_DIR}"
        error "Please run this script from the cloned FORGE repository."
        exit 1
    fi
}

install_skills() {
    step 2 "Installing skills..."

    mkdir -p "${CLAUDE_DIR}/skills"
    mkdir -p "${FORGE_DIR}/skills"

    # ── Hub-only architecture ──
    # Only the forge hub goes into ~/.claude/skills/ (visible to Claude Code).
    # All satellite skills go into ~/.forge/skills/ (loaded on demand by the hub).

    # Clean up old forge-* satellites from ~/.claude/skills/ (v1 layout migration)
    for skill_dir in "${CLAUDE_DIR}/skills/"forge-*/; do
        [ -d "$skill_dir" ] || continue
        local skill_name
        skill_name="$(basename "$skill_dir")"
        rm -rf "$skill_dir"
        info "Migrated from ~/.claude/skills/: ${skill_name}"
    done

    # Also remove old forge hub if present (will be re-copied)
    rm -rf "${CLAUDE_DIR}/skills/forge"

    # Remove deprecated skills from both locations
    REMOVED_SKILLS="forge-deploy"
    for skill in $REMOVED_SKILLS; do
        for loc in "${CLAUDE_DIR}/skills/${skill}" "${FORGE_DIR}/skills/${skill}"; do
            if [ -d "$loc" ]; then
                rm -rf "$loc"
                warn "Removed deprecated skill: ${skill}"
            fi
        done
    done

    # Install the hub (forge/) into ~/.claude/skills/
    cp -r "${SCRIPT_DIR}/skills/forge" "${CLAUDE_DIR}/skills/forge"
    ok "Hub installed: ~/.claude/skills/forge/"

    # Install all satellite skills into ~/.forge/skills/
    SATELLITE_COUNT=0
    for skill_dir in "${SCRIPT_DIR}/skills/"*/; do
        local skill_name
        skill_name="$(basename "$skill_dir")"
        # Skip the hub — it's already installed above
        [ "$skill_name" = "forge" ] && continue
        rm -rf "${FORGE_DIR}/skills/${skill_name}"
        cp -r "$skill_dir" "${FORGE_DIR}/skills/${skill_name}"
        SATELLITE_COUNT=$((SATELLITE_COUNT + 1))
    done
    ok "Satellites installed: ${SATELLITE_COUNT} skills to ~/.forge/skills/"

    # Install Business Pack satellites (if previously installed or first install)
    if [ -d "${SCRIPT_DIR}/packs/business" ]; then
        for dir in "${SCRIPT_DIR}/packs/business/"forge-*/; do
            [ -d "$dir" ] || continue
            local bp_skill
            bp_skill="$(basename "$dir")"
            if [ -d "${FORGE_DIR}/skills/${bp_skill}" ]; then
                rm -rf "${FORGE_DIR}/skills/${bp_skill}"
                cp -r "$dir" "${FORGE_DIR}/skills/${bp_skill}"
            fi
        done
    fi

    # Verify core hub exists
    if [ ! -f "${CLAUDE_DIR}/skills/forge/SKILL.md" ]; then
        error "Hub forge/SKILL.md not found after copy. Installation failed."
        exit 1
    fi

    SKILL_COUNT=$((SATELLITE_COUNT + 1))
    ok "Total: ${SKILL_COUNT} skills (1 hub + ${SATELLITE_COUNT} satellites)"

    # Write version file
    if [ -f "${SCRIPT_DIR}/VERSION" ]; then
        cp "${SCRIPT_DIR}/VERSION" "${CLAUDE_DIR}/skills/forge/.forge-version"
        ok "Version $(cat "${CLAUDE_DIR}/skills/forge/.forge-version" | tr -d '[:space:]') recorded"
    fi

    # Note: All hooks (update-check, auto-router, memory-sync, etc.)
    # are installed in step 5 via forge-hooks-setup.sh
}

# ─── [3/6] Update ~/.claude/CLAUDE.md ────────────────────────────────────────

inject_claude_md() {
    step 3 "Configuring ~/.claude/CLAUDE.md..."

    if [ -f "${SCRIPT_DIR}/scripts/inject-claude-md.sh" ]; then
        FORGE_YES="$AUTO_YES" bash "${SCRIPT_DIR}/scripts/inject-claude-md.sh"
    else
        warn "inject-claude-md.sh not found — skipping CLAUDE.md configuration."
    fi
}

# ─── [4/6] Check Python & vector memory ─────────────────────────────────────

check_python() {
    step 4 "Checking Python..."

    local py_cmd=""
    local py_version=""
    local py_major=""
    local py_minor=""

    # Try python3 first, then python
    for cmd in python3 python; do
        if command -v "$cmd" &>/dev/null; then
            py_version=$("$cmd" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || true)
            if [ -n "$py_version" ]; then
                py_major=$(echo "$py_version" | cut -d. -f1)
                py_minor=$(echo "$py_version" | cut -d. -f2)
                if [ "$py_major" -ge 3 ] && [ "$py_minor" -ge 9 ]; then
                    py_cmd="$cmd"
                    break
                fi
            fi
        fi
    done

    if [ -z "$py_cmd" ]; then
        warn "Python 3.9+ not found — skipping vector memory setup."
        echo ""
        info "Vector memory is optional. FORGE works without it (Markdown memory is always active)."
        info "To install Python 3.9+ later:"
        case "${OS}" in
            macOS)
                info "  brew install python@3.12" ;;
            Linux|WSL)
                if command -v apt &>/dev/null; then
                    info "  sudo apt update && sudo apt install python3 python3-venv"
                elif command -v dnf &>/dev/null; then
                    info "  sudo dnf install python3"
                elif command -v pacman &>/dev/null; then
                    info "  sudo pacman -S python"
                else
                    info "  https://www.python.org/downloads/"
                fi
                ;;
            *)
                info "  https://www.python.org/downloads/" ;;
        esac
        info "Then run: bash ~/.claude/skills/forge/scripts/forge-memory/setup.sh"
        return
    fi

    ok "Python ${py_version} detected (via ${py_cmd})"
    info "Installing vector memory (Python venv + ~80 MB model)..."
    if bash "${CLAUDE_DIR}/skills/forge/scripts/forge-memory/setup.sh" --auto; then
        VECTOR_MEMORY_INSTALLED=true
        ok "Vector memory installed"
    else
        warn "Vector memory setup failed. You can retry later:"
        warn "  bash ~/.claude/skills/forge/scripts/forge-memory/setup.sh"
    fi
}

# ─── [5/6] FORGE Hooks ─────────────────────────────────────────────────────

install_forge_hooks() {
    step 5 "Installing FORGE Hooks..."

    if FORGE_AUTO="$AUTO_YES" bash "${CLAUDE_DIR}/skills/forge/scripts/forge-hooks-setup.sh"; then
        FORGE_HOOKS_INSTALLED=true
        ok "FORGE Hooks installed"
    else
        warn "FORGE Hooks setup failed. You can retry later:"
        warn "  bash ~/.claude/skills/forge/scripts/forge-hooks-setup.sh"
        FORGE_HOOKS_INSTALLED=false
    fi
}


# --- RTK full setup: Bash hook + native hook + telemetry + CLAUDE.md --------

setup_rtk_hooks() {
    if [ "$RTK_INSTALLED" != true ]; then
        return
    fi

    # (a) RTK Bash hook via rtk init -g
    if command -v rtk &>/dev/null; then
        if rtk init --show 2>/dev/null | grep -q "Hook: not found"; then
            info "Configuring RTK Bash hook..."
            rtk init -g --auto-patch 2>/dev/null \
                && ok "RTK Bash hook configured" \
                || warn "rtk init -g failed (run manually: rtk init -g --auto-patch)"
        else
            ok "RTK Bash hook: already configured"
        fi
    fi

    # (b) Disable anonymous telemetry
    local rc_file=""
    case "${OS}" in
        macOS) rc_file="${HOME}/.zshrc" ;;
        *) rc_file="${HOME}/.bashrc" ;;
    esac
    if [ -n "$rc_file" ] && ! grep -q "RTK_TELEMETRY_DISABLED" "${rc_file}" 2>/dev/null; then
        echo 'export RTK_TELEMETRY_DISABLED=1' >> "${rc_file}"
        ok "RTK telemetry disabled (${rc_file})"
    fi

    # (c) RTK native hook for Read/Grep/Glob (bundled in FORGE hooks/)
    local hook_src="${SCRIPT_DIR}/hooks/rtk-native-hook.sh"
    local hook_dst="${CLAUDE_DIR}/hooks/rtk-native-hook.sh"
    if [ -f "${hook_src}" ]; then
        mkdir -p "${CLAUDE_DIR}/hooks"
        cp -f "${hook_src}" "${hook_dst}"
        chmod +x "${hook_dst}"
        # Patch settings.json idempotently
        local settings="${CLAUDE_DIR}/settings.json"
        if [ -f "${settings}" ] && command -v python3 &>/dev/null; then
            python3 - "${settings}" "${hook_dst}" <<'PYSCRIPT'
import json, sys
sp, hp = sys.argv[1], sys.argv[2]
with open(sp) as f: cfg = json.load(f)
pre = cfg.setdefault('hooks', {}).setdefault('PreToolUse', [])
if not any('rtk-native-hook' in str(e) for e in pre):
    pre.append({'matcher': 'Read|Grep|Glob', 'hooks': [{'type': 'command', 'command': hp}]})
    with open(sp, 'w') as f: json.dump(cfg, f, indent=2)
    print('settings.json patched')
PYSCRIPT
            ok "RTK native hook registered in settings.json (Read/Grep/Glob)"
        else
            warn "settings.json not found or python3 missing -- add hook manually"
        fi
    else
        warn "hooks/rtk-native-hook.sh not found in FORGE directory -- skipping"
    fi

    # (d) Inject RTK section into ~/.claude/CLAUDE.md
    if [ -f "${SCRIPT_DIR}/scripts/inject-rtk-claude-md.sh" ]; then
        bash "${SCRIPT_DIR}/scripts/inject-rtk-claude-md.sh" 2>/dev/null \
            && ok "RTK section added/updated in ~/.claude/CLAUDE.md"
    fi
}

# ─── [6/7] RTK (Token Optimization) ─────────────────────────────────────────

check_rtk() {
    step 6 "Checking RTK (token optimizer)..."

    if command -v rtk &>/dev/null; then
        RTK_INSTALLED=true
        ok "RTK detected ($(rtk --version 2>/dev/null || echo 'installed'))"
        info "FORGE will use RTK for output compression (60-90% token savings)"
    fi

    echo ""
    info "RTK (Rust Token Killer) compresses command outputs before they reach Claude."
    info "Reduces token consumption by 60-90% on git, test, build, and lint commands."
    info "More info: https://github.com/rtk-ai/rtk"
    echo ""

    if [ "$AUTO_YES" = true ] || [ -t 0 ]; then
        if [ "$AUTO_YES" = true ]; then
            REPLY="y"
        else
            printf "  Install RTK? [y/N] "
            read -r REPLY < /dev/tty
        fi
        case "$REPLY" in
            [yY]|[yY][eE][sS])
                if command -v brew &>/dev/null; then
                    info "Installing via Homebrew..."
                    if brew install rtk 2>/dev/null; then
                        RTK_INSTALLED=true
                        ok "RTK installed via Homebrew"
                    else
                        warn "Homebrew install failed. Trying curl..."
                        if curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh 2>/dev/null; then
                            RTK_INSTALLED=true
                            ok "RTK installed via curl"
                        else
                            warn "RTK installation failed. Install manually: brew install rtk"
                        fi
                    fi
                else
                    info "Installing via curl..."
                    if curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh 2>/dev/null; then
                        RTK_INSTALLED=true
                        ok "RTK installed"
                    else
                        warn "RTK installation failed. Install manually: https://github.com/rtk-ai/rtk"
                    fi
                fi
                ;;
            *)
                info "Skipped. FORGE will use built-in token-saver (less efficient)."
                info "Install later: brew install rtk"
                ;;
        esac
    else
        info "Non-interactive mode: skipping RTK installation."
        info "Install later: brew install rtk"
    fi

    setup_rtk_hooks
}

# ─── [7/7] Verify installation ──────────────────────────────────────────────

verify_installation() {
    step 7 "Verifying installation..."

    local errors=0

    # Check core skill
    if [ -f "${CLAUDE_DIR}/skills/forge/SKILL.md" ]; then
        ok "Core skill: forge"
    else
        error "Missing: forge/SKILL.md"
        errors=$((errors + 1))
    fi

    # Check satellite skills in ~/.forge/skills/
    for skill in forge-auto forge-build forge-verify forge-plan forge-init forge-ux forge-loop forge-analyze forge-audit forge-quick-test forge-audit-skill forge-stories forge-architect forge-party forge-team forge-memory forge-quick-spec forge-review forge-resume forge-status forge-update; do
        if [ -f "${FORGE_DIR}/skills/${skill}/SKILL.md" ]; then
            ok "Skill: ${skill}"
        else
            warn "Missing: ${skill}/SKILL.md"
        fi
    done

    # Check vector memory if installed
    if [ "$VECTOR_MEMORY_INSTALLED" = true ]; then
        if command -v forge-memory &>/dev/null; then
            ok "Vector memory CLI: forge-memory"
        else
            warn "forge-memory CLI not in PATH (may need to restart your shell)"
        fi
    fi

    # Check FORGE Hooks
    if [ "${FORGE_HOOKS_INSTALLED:-false}" = true ]; then
        local hooks_ok=true
        for hook_file in bash-interceptor.js token-saver.sh forge-update-check.sh forge-memory-sync.sh forge-skill-tracker.sh; do
            if [ -f "${HOME}/.claude/hooks/${hook_file}" ]; then
                ok "Hook: ${hook_file}"
            else
                warn "Hook missing: ${hook_file}"
                hooks_ok=false
            fi
        done
        # statusline.sh is optional
        if [ -f "${HOME}/.claude/hooks/statusline.sh" ]; then
            ok "Hook: statusline.sh (optional)"
        fi
        # RTK native hook (optional)
        if [ -f "${HOME}/.claude/hooks/rtk-native-hook.sh" ]; then
            ok "Hook: rtk-native-hook.sh (Read/Grep/Glob compression)"
        fi
        if [ "$hooks_ok" = true ]; then
            ok "All FORGE hooks installed"
        fi
    fi

    if [ "$errors" -gt 0 ]; then
        error "Installation completed with errors."
        exit 1
    fi
}

# ─── Summary ─────────────────────────────────────────────────────────────────

print_summary() {
    echo ""
    printf '%b\n' "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    printf '%b\n' "${GREEN}  FORGE installed successfully${NC}"
    printf '%b\n' "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  Installed:"
    printf '%b\n' "    ${GREEN}✓${NC} Hub: ~/.claude/skills/forge/"
    printf '%b\n' "    ${GREEN}✓${NC} ${SATELLITE_COUNT} satellites: ~/.forge/skills/"
    if [ "$VECTOR_MEMORY_INSTALLED" = true ]; then
        printf '%b\n' "    ${GREEN}✓${NC} Vector memory (forge-memory CLI)"
    else
        printf '%b\n' "    ${YELLOW}--${NC} Vector memory (not installed)"
    fi
    if [ "${FORGE_HOOKS_INSTALLED:-false}" = true ]; then
        local sl_status=""
        if [ -f "${HOME}/.claude/hooks/statusline.sh" ]; then
            sl_status=", status line"
        fi
        printf '%b\n' "    ${GREEN}✓${NC} FORGE Hooks (bash-interceptor, token-saver, update-check, memory-sync${sl_status})"
    else
        printf '%b\n' "    ${YELLOW}--${NC} FORGE Hooks (not installed)"
    fi
    if [ "$RTK_INSTALLED" = true ]; then
        printf '%b\n' "    ${GREEN}✓${NC} RTK token optimizer (Bash auto-rewrite + native Read/Grep/Glob hook)"
        if [ -f "${HOME}/.claude/hooks/rtk-native-hook.sh" ]; then
            printf '%b\n' "    ${GREEN}✓${NC} RTK native hook: 80-85% compression on .ts/.js/.py source files"
        fi
    else
        printf '%b\n' "    ${YELLOW}--${NC} RTK (not installed -- using built-in token-saver)"
    fi
    # Suggest Business Pack if not installed
    local has_business_pack=false
    for bp_skill in forge-marketing forge-copywriting forge-seo forge-geo forge-legal forge-security-pro forge-business-strategy forge-strategy-panel; do
        if [ -d "${FORGE_DIR}/skills/${bp_skill}" ]; then
            has_business_pack=true
            break
        fi
    done

    if [ "$has_business_pack" = false ] && [ -d "${SCRIPT_DIR}/packs/business" ]; then
        echo ""
        printf '%b\n' "  ${YELLOW}Tip:${NC} FORGE Business Pack available (marketing, SEO, legal, security, strategy)."
        echo "        Install with: /forge-update --pack business"
    fi

    echo ""
    echo "  Next steps:"
    echo "    1. Open Claude Code in your project"
    echo "    2. Run /forge-init to initialize FORGE"
    echo "    3. Run /forge-auto \"your goal\" to start building"
    echo ""
}

# ─── Main ────────────────────────────────────────────────────────────────────

main() {
    detect_os
    verify_source
    install_skills
    inject_claude_md
    check_python
    install_forge_hooks
    check_rtk
    verify_installation
    print_summary
}

main
