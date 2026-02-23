#!/bin/bash
# FORGE Project Initializer
# Usage: forge-init.sh [project-path] [--scale quick|standard|enterprise] [--help]

set -euo pipefail

# ─── Defaults ───────────────────────────────────────────────────
PROJECT_PATH="."
SCALE="auto"

# ─── Help ───────────────────────────────────────────────────────
show_help() {
  cat << 'HELPEOF'
Usage: forge-init.sh [project-path] [options]

Initialize FORGE in a new or existing project. Creates the .forge/ structure,
config, CLAUDE.md, and detects the tech stack.

Arguments:
  project-path          Path to the project (default: current directory)

Options:
  --scale SCALE         Project scale: quick | standard | enterprise | auto (default: auto)
  -h, --help            Show this help message

Examples:
  forge-init.sh
  forge-init.sh ./my-project
  forge-init.sh ./my-project --scale standard
HELPEOF
  exit 0
}

# ─── Parse Arguments ────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help) show_help ;;
    --scale) SCALE="${2:-auto}"; shift 2 ;;
    -*) echo "Error: Unknown option '$1'. Use --help for usage."; exit 1 ;;
    *) PROJECT_PATH="$1"; shift ;;
  esac
done

echo "🔨 FORGE — Initializing project at: ${PROJECT_PATH}"

# Create directory structure
mkdir -p "${PROJECT_PATH}/.forge"
mkdir -p "${PROJECT_PATH}/docs/stories"
mkdir -p "${PROJECT_PATH}/docs/adrs"
mkdir -p "${PROJECT_PATH}/.forge/memory"
mkdir -p "${PROJECT_PATH}/.forge/memory/sessions"
mkdir -p "${PROJECT_PATH}/.forge/memory/agents"

# Auto-detect project type
detect_project_type() {
  local path="$1"
  if [ -f "${path}/package.json" ]; then
    # Search in dependencies and devDependencies only
    local deps=""
    if command -v python3 &>/dev/null; then
      deps=$(python3 -c "
import json, sys
try:
    with open('${path}/package.json') as f:
        pkg = json.load(f)
    d = list(pkg.get('dependencies', {}).keys()) + list(pkg.get('devDependencies', {}).keys())
    print(' '.join(d))
except: pass
" 2>/dev/null || echo "")
    else
      deps=$(cat "${path}/package.json" 2>/dev/null || echo "")
    fi
    if echo "$deps" | grep -q "@angular/core"; then
      echo "angular"
    elif echo "$deps" | grep -q "next"; then
      echo "nextjs"
    elif echo "$deps" | grep -q "express"; then
      echo "node-express"
    else
      echo "node"
    fi
  elif [ -f "${path}/pom.xml" ]; then
    echo "java"
  elif ls "${path}"/*.csproj &>/dev/null 2>&1; then
    echo "dotnet"
  elif [ -f "${path}/Package.swift" ]; then
    echo "swift"
  elif [ -f "${path}/composer.json" ]; then
    echo "php"
  elif [ -f "${path}/go.mod" ]; then
    echo "go"
  elif [ -f "${path}/Cargo.toml" ]; then
    echo "rust"
  elif [ -f "${path}/requirements.txt" ] || [ -f "${path}/pyproject.toml" ]; then
    echo "python"
  else
    echo "unknown"
  fi
}

# Auto-detect language
detect_language() {
  local path="$1"
  if [ -f "${path}/tsconfig.json" ]; then
    echo "typescript"
  elif [ -f "${path}/package.json" ]; then
    echo "javascript"
  elif [ -f "${path}/pom.xml" ]; then
    echo "java"
  elif ls "${path}"/*.csproj &>/dev/null 2>&1; then
    echo "csharp"
  elif [ -f "${path}/Package.swift" ]; then
    echo "swift"
  elif [ -f "${path}/composer.json" ]; then
    echo "php"
  elif [ -f "${path}/go.mod" ]; then
    echo "go"
  elif [ -f "${path}/Cargo.toml" ]; then
    echo "rust"
  elif [ -f "${path}/requirements.txt" ] || [ -f "${path}/pyproject.toml" ]; then
    echo "python"
  else
    echo "unknown"
  fi
}

PROJECT_TYPE=$(detect_project_type "${PROJECT_PATH}")
LANGUAGE=$(detect_language "${PROJECT_PATH}")

echo "  Detected type: ${PROJECT_TYPE}"
echo "  Detected language: ${LANGUAGE}"

# Generate .forge/config.yml
cat > "${PROJECT_PATH}/.forge/config.yml" << EOF
# FORGE Configuration
# Generated: $(date -Iseconds)

project:
  name: "$(basename "$(cd "${PROJECT_PATH}" && pwd)")"
  type: "${PROJECT_TYPE}"
  language: "${LANGUAGE}"
  scale: "${SCALE}"

agents:
  default_set: standard

loop:
  max_iterations: 30
  cost_cap_usd: 10.00
  timeout_minutes: 60
  sandbox:
    enabled: true
    provider: docker
    mount_readonly:
      - ./docs
      - ./references
    mount_readwrite:
      - ./src
      - ./tests
    network: restricted
    allowed_domains:
      - registry.npmjs.org
      - pypi.org
  circuit_breaker:
    consecutive_errors: 3

memory:
  enabled: true
  auto_save: true
  session_logs: true
  agent_memory: true
  vector_search:
    enabled: false
    model: "all-MiniLM-L6-v2"
    auto_sync: true

security:
  audit_skills: true
  sandbox_loops: true
  credential_store: env
  allowed_domains: []

mcp:
  servers: []
  expose: false

n8n:
  enabled: false
  instance_url: ""
  api_key_env: "N8N_API_KEY"

deploy:
  provider: ""
  staging_url: ""
  production_url: ""
  require_approval: true
EOF

# Create initial MEMORY.md
cat > "${PROJECT_PATH}/.forge/memory/MEMORY.md" << EOF
# Project Memory

Initialized: $(date -Iseconds)

## Decisions

(none yet)

## Current State

Project initialized with FORGE.
EOF

# Generate CLAUDE.md if not exists
if [ ! -f "${PROJECT_PATH}/CLAUDE.md" ]; then
  cat > "${PROJECT_PATH}/CLAUDE.md" << EOF
# CLAUDE.md — Generated by FORGE

## Project
- **Name**: $(basename "$(cd "${PROJECT_PATH}" && pwd)")
- **Type**: ${PROJECT_TYPE}
- **Language**: ${LANGUAGE}

## FORGE Commands
- \`/forge-plan\` — Generate/update PRD (PM agent)
- \`/forge-architect\` — Generate/update architecture (Architect agent)
- \`/forge-stories\` — Generate stories from PRD + architecture (SM agent)
- \`/forge-build\` — Implement current story (Dev agent)
- \`/forge-loop "task"\` — Autonomous iteration loop
- \`/forge-verify\` — Run tests and validation (QA agent)
- \`/forge-deploy\` — Deploy to configured environment
- \`/forge-status\` — Project status overview
- \`/forge-audit\` — Security audit (Security agent)

## Conventions
- **Commits**: Conventional format — \`type(scope): description\`
- **Tests**: Required for all production code
- **Branches**: \`feature/\`, \`fix/\`, \`forge/loop-\` prefixes
- **Secrets**: NEVER in code — use environment variables

## Architecture
See \`docs/architecture.md\` when available.

## Current Sprint
See \`docs/stories/backlog.md\` when available.
EOF
fi

# Add FORGE entries to .gitignore (create if it doesn't exist)
FORGE_GITIGNORE_ENTRIES="
# FORGE
.forge/secrets/
.forge/audit.log
.env
.env.*
.forge/memory/index.sqlite*
*.pem
*.key"

if [ -f "${PROJECT_PATH}/.gitignore" ]; then
  if ! grep -q "# FORGE" "${PROJECT_PATH}/.gitignore"; then
    echo "$FORGE_GITIGNORE_ENTRIES" >> "${PROJECT_PATH}/.gitignore"
  fi
else
  echo "$FORGE_GITIGNORE_ENTRIES" > "${PROJECT_PATH}/.gitignore"
fi

# ─── Token Saver Setup (global, idempotent) ─────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
bash "${SCRIPT_DIR}/scripts/token-saver-setup.sh"

echo ""
echo "✅ FORGE initialized successfully!"
echo ""
echo "Next steps:"
echo "  1. Edit .forge/config.yml to customize settings"
echo "  2. Run /forge-plan to start planning"
echo "  3. Run /forge-help for available commands"
