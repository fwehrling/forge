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

info()  { echo -e "${BLUE}→${NC} $1"; }
ok()    { echo -e "${GREEN}✓${NC} $1"; }
warn()  { echo -e "${YELLOW}!${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1" >&2; }
step()  { echo -e "\n${BOLD}[$1/$TOTAL_STEPS] $2${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"
TOTAL_STEPS=6
VECTOR_MEMORY_INSTALLED=false

# ─── Banner ──────────────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}FORGE${NC} — Framework for Orchestrated Resilient Generative Engineering"
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
            read -p "$(echo -e "${YELLOW}?${NC}") Continue anyway? [y/N] " answer
            if [[ ! "${answer}" =~ ^[Yy]$ ]]; then
                info "Installation cancelled. Install WSL and try again."
                exit 0
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

    # Remove existing forge skills (may be symlinks from a previous install method)
    for skill_dir in "${SCRIPT_DIR}/skills/"*/; do
        local skill_name
        skill_name="$(basename "$skill_dir")"
        local target="${CLAUDE_DIR}/skills/${skill_name}"
        if [ -L "$target" ] || [ -d "$target" ]; then
            rm -rf "$target"
        fi
    done

    cp -r "${SCRIPT_DIR}/skills/"* "${CLAUDE_DIR}/skills/"

    # Verify core skill exists
    if [ ! -f "${CLAUDE_DIR}/skills/forge/SKILL.md" ]; then
        error "Core skill forge/SKILL.md not found after copy. Installation failed."
        exit 1
    fi

    SKILL_COUNT=$(find "${CLAUDE_DIR}/skills" -name "SKILL.md" -maxdepth 2 | wc -l | tr -d ' ')
    ok "Installed ${SKILL_COUNT} skills to ${CLAUDE_DIR}/skills/"

    # Write version file
    if [ -f "${SCRIPT_DIR}/VERSION" ]; then
        cp "${SCRIPT_DIR}/VERSION" "${CLAUDE_DIR}/skills/forge/.forge-version"
        ok "Version $(cat "${CLAUDE_DIR}/skills/forge/.forge-version" | tr -d '[:space:]') recorded"
    fi

    # Install update-check hook
    mkdir -p "${CLAUDE_DIR}/hooks"
    if [ -f "${SCRIPT_DIR}/hooks/forge-update-check.sh" ]; then
        cp "${SCRIPT_DIR}/hooks/forge-update-check.sh" "${CLAUDE_DIR}/hooks/forge-update-check.sh"
        chmod +x "${CLAUDE_DIR}/hooks/forge-update-check.sh"
        ok "Update check hook installed"
    fi

    # Add SessionStart hook to settings.json if not already present
    local settings_file="${CLAUDE_DIR}/settings.json"
    if [ -f "$settings_file" ]; then
        if ! grep -q 'forge-update-check' "$settings_file" 2>/dev/null; then
            if command -v node &>/dev/null; then
                node -e "
                    const fs = require('fs');
                    const s = JSON.parse(fs.readFileSync('$settings_file', 'utf8'));
                    if (!s.hooks) s.hooks = {};
                    if (!s.hooks.SessionStart) s.hooks.SessionStart = [];
                    s.hooks.SessionStart.push({
                        matcher: '',
                        hooks: [{ type: 'command', command: 'bash ~/.claude/hooks/forge-update-check.sh' }]
                    });
                    fs.writeFileSync('$settings_file', JSON.stringify(s, null, 2) + '\n');
                "
                ok "SessionStart hook added to settings.json"
            else
                warn "Node.js not found — add SessionStart hook manually to ${settings_file}"
            fi
        fi
    fi
}

# ─── [3/6] Update ~/.claude/CLAUDE.md ────────────────────────────────────────

inject_claude_md() {
    step 3 "Configuring ~/.claude/CLAUDE.md..."

    if [ -f "${SCRIPT_DIR}/scripts/inject-claude-md.sh" ]; then
        bash "${SCRIPT_DIR}/scripts/inject-claude-md.sh"
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
    echo ""
    read -p "$(echo -e "${YELLOW}?${NC}") Install vector memory? (Python venv + ~80 MB model download) [y/N] " answer
    if [[ "${answer}" =~ ^[Yy]$ ]]; then
        info "Running forge-memory setup..."
        if bash "${CLAUDE_DIR}/skills/forge/scripts/forge-memory/setup.sh"; then
            VECTOR_MEMORY_INSTALLED=true
            ok "Vector memory installed"
        else
            warn "Vector memory setup failed. You can retry later:"
            warn "  bash ~/.claude/skills/forge/scripts/forge-memory/setup.sh"
        fi
    else
        info "Skipped. Run later: bash ~/.claude/skills/forge/scripts/forge-memory/setup.sh"
    fi
}

# ─── [5/6] Token Saver ─────────────────────────────────────────────────────

install_token_saver() {
    step 5 "Installing Token Saver..."

    if bash "${CLAUDE_DIR}/skills/forge/scripts/token-saver-setup.sh"; then
        TOKEN_SAVER_INSTALLED=true
        ok "Token Saver installed"
    else
        warn "Token Saver setup failed. You can retry later:"
        warn "  bash ~/.claude/skills/forge/scripts/token-saver-setup.sh"
        TOKEN_SAVER_INSTALLED=false
    fi
}

# ─── [6/6] Verify installation ──────────────────────────────────────────────

verify_installation() {
    step 6 "Verifying installation..."

    local errors=0

    # Check core skill
    if [ -f "${CLAUDE_DIR}/skills/forge/SKILL.md" ]; then
        ok "Core skill: forge"
    else
        error "Missing: forge/SKILL.md"
        errors=$((errors + 1))
    fi

    # Check key skills
    for skill in forge-auto forge-build forge-verify forge-plan forge-init forge-ux forge-deploy forge-loop forge-analyze forge-audit forge-quick-test forge-audit-skill forge-stories forge-architect forge-party forge-team forge-memory forge-quick-spec forge-review forge-resume forge-status forge-update; do
        if [ -f "${CLAUDE_DIR}/skills/${skill}/SKILL.md" ]; then
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

    # Check Token Saver
    if [ "${TOKEN_SAVER_INSTALLED:-false}" = true ]; then
        if [ -f "${HOME}/.claude/hooks/output-filter.js" ] && [ -f "${HOME}/.claude/hooks/token-saver.sh" ]; then
            ok "Token Saver: output filtering hooks"
        else
            warn "Token Saver: hook files missing"
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
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  FORGE installed successfully${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  Installed:"
    echo "    ${GREEN}✓${NC} ${SKILL_COUNT} skills → ${CLAUDE_DIR}/skills/"
    if [ "$VECTOR_MEMORY_INSTALLED" = true ]; then
        echo "    ${GREEN}✓${NC} Vector memory (forge-memory CLI)"
    else
        echo "    ${YELLOW}–${NC} Vector memory (not installed)"
    fi
    if [ "${TOKEN_SAVER_INSTALLED:-false}" = true ]; then
        echo "    ${GREEN}✓${NC} Token Saver (output filtering hooks)"
    else
        echo "    ${YELLOW}–${NC} Token Saver (not installed)"
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
    install_token_saver
    verify_installation
    print_summary
}

main
