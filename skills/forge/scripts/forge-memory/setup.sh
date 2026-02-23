#!/bin/bash
# FORGE Vector Memory — Installation
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="${SCRIPT_DIR}/.venv"

echo "🧠 FORGE Vector Memory — Installation"
echo ""

# Create isolated venv
if [ ! -d "${VENV_DIR}" ]; then
    echo "→ Creating virtual environment..."
    python3 -m venv "${VENV_DIR}"
fi

# Activate and install deps
echo "→ Installing dependencies..."
"${VENV_DIR}/bin/pip" install --quiet --upgrade pip
"${VENV_DIR}/bin/pip" install --quiet -r "${SCRIPT_DIR}/requirements.txt"

# Pre-download model
echo "→ Pre-downloading embedding model (all-MiniLM-L6-v2)..."
"${VENV_DIR}/bin/python" -c "from sentence_transformers import SentenceTransformer; SentenceTransformer('all-MiniLM-L6-v2')"

# Create wrapper script
WRAPPER="${SCRIPT_DIR}/forge-memory"
cat > "${WRAPPER}" << 'WRAPPER_EOF'
#!/bin/bash
# Resolve symlinks to find the real script directory
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
    DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
exec "${SCRIPT_DIR}/.venv/bin/python" "${SCRIPT_DIR}/cli.py" "$@"
WRAPPER_EOF
chmod +x "${WRAPPER}"

# ---------------------------------------------------------------------------
# Add forge-memory to PATH (symlink)
# ---------------------------------------------------------------------------
echo ""
echo "→ Adding forge-memory to PATH..."

SYMLINK_INSTALLED=false

# Try ~/.local/bin first (no sudo needed)
LOCAL_BIN="${HOME}/.local/bin"
if [ -d "${LOCAL_BIN}" ] || mkdir -p "${LOCAL_BIN}" 2>/dev/null; then
    ln -sf "${WRAPPER}" "${LOCAL_BIN}/forge-memory"
    SYMLINK_INSTALLED=true
    # Ensure ~/.local/bin is in PATH (for current and future shells)
    if ! echo "$PATH" | grep -q "${LOCAL_BIN}"; then
        SHELL_RC=""
        if [ -f "${HOME}/.zshrc" ]; then
            SHELL_RC="${HOME}/.zshrc"
        elif [ -f "${HOME}/.bashrc" ]; then
            SHELL_RC="${HOME}/.bashrc"
        fi
        if [ -n "${SHELL_RC}" ]; then
            if ! grep -q '\.local/bin' "${SHELL_RC}" 2>/dev/null; then
                echo '' >> "${SHELL_RC}"
                echo '# FORGE Vector Memory' >> "${SHELL_RC}"
                echo 'export PATH="${HOME}/.local/bin:${PATH}"' >> "${SHELL_RC}"
                echo "  Added ~/.local/bin to PATH in ${SHELL_RC}"
            fi
        fi
        export PATH="${LOCAL_BIN}:${PATH}"
    fi
    echo "  Symlink: ${LOCAL_BIN}/forge-memory -> ${WRAPPER}"
fi

# Fallback: try /usr/local/bin (may need sudo)
if [ "${SYMLINK_INSTALLED}" = false ]; then
    if ln -sf "${WRAPPER}" /usr/local/bin/forge-memory 2>/dev/null; then
        SYMLINK_INSTALLED=true
        echo "  Symlink: /usr/local/bin/forge-memory -> ${WRAPPER}"
    elif command -v sudo &>/dev/null; then
        echo "  ~/.local/bin not available, trying /usr/local/bin with sudo..."
        if sudo ln -sf "${WRAPPER}" /usr/local/bin/forge-memory 2>/dev/null; then
            SYMLINK_INSTALLED=true
            echo "  Symlink: /usr/local/bin/forge-memory -> ${WRAPPER}"
        fi
    fi
fi

if [ "${SYMLINK_INSTALLED}" = false ]; then
    echo "  ⚠️  Could not add forge-memory to PATH automatically."
    echo "  Add this to your shell profile:"
    echo "    export PATH=\"${SCRIPT_DIR}:\${PATH}\""
fi

# ---------------------------------------------------------------------------
# Post-install: detect project and propose initial sync
# ---------------------------------------------------------------------------
echo ""
echo "✅ FORGE Vector Memory installed!"
echo ""

# Check if we're inside a FORGE project (or a parent has .forge/memory/)
PROJECT_ROOT=""
CHECK_DIR="$(pwd)"
while [ "${CHECK_DIR}" != "/" ]; do
    if [ -d "${CHECK_DIR}/.forge/memory" ]; then
        PROJECT_ROOT="${CHECK_DIR}"
        break
    fi
    CHECK_DIR="$(dirname "${CHECK_DIR}")"
done

if [ -n "${PROJECT_ROOT}" ]; then
    MEMORY_DIR="${PROJECT_ROOT}/.forge/memory"
    DB_FILE="${MEMORY_DIR}/index.sqlite"
    MEMORY_FILE="${MEMORY_DIR}/MEMORY.md"

    echo "📂 FORGE project detected: ${PROJECT_ROOT}"
    echo ""

    # Check if MEMORY.md needs enrichment (still has placeholders)
    if grep -q "à compléter" "${MEMORY_FILE}" 2>/dev/null; then
        echo "📝 MEMORY.md contains placeholders — it needs enrichment."
        echo "   Run your FORGE agents (/forge-architect, /forge-plan) to populate it,"
        echo "   or manually fill in project context, decisions, and patterns."
        echo ""
    fi

    # Check if index is empty or stale
    NEEDS_SYNC=false
    if [ ! -f "${DB_FILE}" ]; then
        echo "🔍 No index found — initial sync recommended."
        NEEDS_SYNC=true
    else
        FILE_COUNT=$("${WRAPPER}" status --json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('file_count',0))" 2>/dev/null || echo "0")
        MD_COUNT=$(find "${MEMORY_DIR}" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
        if [ "${FILE_COUNT}" -lt "${MD_COUNT}" ]; then
            echo "🔍 Index has ${FILE_COUNT} file(s) but ${MD_COUNT} .md file(s) found — sync recommended."
            NEEDS_SYNC=true
        else
            echo "✅ Index is up to date (${FILE_COUNT} file(s), synced)."
        fi
    fi

    if [ "${NEEDS_SYNC}" = true ]; then
        echo ""
        read -r -p "→ Run initial sync now? [Y/n] " REPLY
        REPLY="${REPLY:-Y}"
        if [[ "${REPLY}" =~ ^[Yy]$ ]]; then
            echo ""
            "${WRAPPER}" sync --verbose
        else
            echo "  Skipped. Run 'forge-memory sync' when ready."
        fi
    fi
else
    echo "   No FORGE project detected in current directory."
    echo "   Navigate to a project with .forge/memory/ and run: forge-memory sync"
fi

echo ""
echo "   Usage: forge-memory sync|search|status|reset"
