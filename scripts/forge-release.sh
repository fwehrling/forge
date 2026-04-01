#!/usr/bin/env bash
# FORGE -- Create an annotated git tag and push it to trigger VPS deployment
# Usage:
#   forge-release.sh
set -euo pipefail

# --- Colors -------------------------------------------------------------------

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

ok()  { printf '%b\n' "${GREEN}[OK]${NC} $1"; }
err() { printf '%b\n' "${RED}[ERR]${NC} $1" >&2; }
die() { err "$1"; exit 1; }

# --- Paths --------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
VERSION_FILE="${REPO_ROOT}/VERSION"

# --- Pre-checks ---------------------------------------------------------------

printf '\n'
printf '%b\n' "${BOLD}=== FORGE Release ===${NC}"
printf '\n'

# Verify current branch is main
CURRENT_BRANCH="$(git -C "${REPO_ROOT}" rev-parse --abbrev-ref HEAD)"
if [ "${CURRENT_BRANCH}" != "main" ]; then
    die "Must be on branch 'main', currently on '${CURRENT_BRANCH}'"
fi

# Pull latest
git -C "${REPO_ROOT}" pull --rebase
ok "Pulled latest main"

# Read version
if [ ! -f "${VERSION_FILE}" ]; then
    die "VERSION file not found: ${VERSION_FILE}"
fi
VERSION="$(cat "${VERSION_FILE}")"
TAG="v${VERSION}"
ok "Version: ${VERSION}"

# Verify tag does not already exist
if git -C "${REPO_ROOT}" tag | grep -qxF "${TAG}"; then
    die "Tag ${TAG} already exists. Bump the version first."
fi
ok "Tag ${TAG} does not exist yet"

# Verify latest commit message contains "release vX.Y.Z"
LATEST_MSG="$(git -C "${REPO_ROOT}" log -1 --pretty=format:"%s")"
if ! echo "${LATEST_MSG}" | grep -qF "release ${TAG}"; then
    die "Latest commit does not contain 'release ${TAG}'. Got: '${LATEST_MSG}'. Merge the ship PR first."
fi
ok "Release commit found on main"

# --- Tag + Push ---------------------------------------------------------------

git -C "${REPO_ROOT}" tag -a "${TAG}" -m "release ${TAG}"
ok "Tag: ${TAG} (annotated)"

git -C "${REPO_ROOT}" push origin "${TAG}"
ok "Pushed ${TAG} to origin"

# --- Summary ------------------------------------------------------------------

printf '\n'
printf '%b\n' "Version: ${VERSION}"
printf '%b\n' "Tag: ${TAG}"
printf '%b\n' "Deploy: triggered on VPS via GitHub webhook"
printf '\n'
