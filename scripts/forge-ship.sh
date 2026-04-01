#!/usr/bin/env bash
# FORGE -- Ship: create annotated tag and push to trigger deployment
# Usage:
#   forge-ship.sh
set -euo pipefail

# ─── Colors ───────────────────────────────────────────────────────────────────

if [ -t 1 ]; then
    GREEN='\033[0;32m' RED='\033[0;31m' BOLD='\033[1m' NC='\033[0m'
else
    GREEN='' RED='' BOLD='' NC=''
fi

ok()  { printf '%b\n' "${GREEN}[ok]${NC} $1"; }
err() { printf '%b\n' "${RED}[x] ${NC}$1" >&2; }
die() { err "$1"; exit 1; }

# ─── Paths ────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
VERSION_FILE="${REPO_ROOT}/VERSION"

# ─── Pre-checks ──────────────────────────────────────────────────────────────

CURRENT_BRANCH="$(git -C "${REPO_ROOT}" rev-parse --abbrev-ref HEAD)"
if [ "${CURRENT_BRANCH}" != "main" ]; then
    die "Must be on 'main' to ship. Currently on '${CURRENT_BRANCH}'."
fi

git -C "${REPO_ROOT}" pull --rebase origin main
ok "main is up to date"

VERSION="$(cat "${VERSION_FILE}")"
TAG="v${VERSION}"

if git -C "${REPO_ROOT}" tag | grep -qxF "${TAG}"; then
    die "Tag ${TAG} already exists."
fi
ok "Version: ${VERSION}"

LATEST_MSG="$(git -C "${REPO_ROOT}" log -1 --pretty=format:"%s")"
if ! echo "${LATEST_MSG}" | grep -qF "release v${VERSION}"; then
    die "Latest commit does not match 'release v${VERSION}'. Got: '${LATEST_MSG}'. Run /forge:release first."
fi
ok "Release commit found"

# ─── Tag + Push ──────────────────────────────────────────────────────────────

git -C "${REPO_ROOT}" tag -a "${TAG}" -m "release ${TAG}"
ok "Created tag: ${TAG}"

git -C "${REPO_ROOT}" push origin "${TAG}"
ok "Pushed ${TAG} to origin"

# ─── Summary ─────────────────────────────────────────────────────────────────

printf '\n'
printf '%b\n' "${BOLD}=== FORGE Ship ===${NC}"
printf '%b\n' "  Tag: ${GREEN}${TAG}${NC}"
printf '%b\n' "  Deployment triggered via webhook"
printf '\n'
