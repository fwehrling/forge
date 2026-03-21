#!/usr/bin/env bash
# FORGE Memory Stop Hook — consolidate + sync on session end
# Catches memory updates that skills didn't save (crash, cancel, etc.)

set -e

# Find project root by walking up to .forge/memory/
find_forge_root() {
  local dir="$PWD"
  while [ "$dir" != "/" ]; do
    if [ -d "$dir/.forge/memory" ]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

# Only run if forge-memory CLI is available
command -v forge-memory >/dev/null 2>&1 || exit 0

# Only run if we're in a FORGE project
PROJECT_ROOT=$(find_forge_root) || exit 0

# Consolidate and sync silently
cd "$PROJECT_ROOT"
forge-memory consolidate >/dev/null 2>&1 || true
forge-memory sync >/dev/null 2>&1 || true
