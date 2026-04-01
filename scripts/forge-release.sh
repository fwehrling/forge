#!/usr/bin/env bash
# FORGE -- Release: bump version, update CHANGELOG + README, commit, merge to main, push
# No tag = no deployment triggered
# Usage:
#   forge-release.sh [major|minor|patch]   # default: auto-detect from Conventional Commits
set -euo pipefail

# ─── Colors ───────────────────────────────────────────────────────────────────

if [ -t 1 ]; then
    GREEN='\033[0;32m' YELLOW='\033[1;33m' BLUE='\033[0;34m'
    RED='\033[0;31m' BOLD='\033[1m' NC='\033[0m'
else
    GREEN='' YELLOW='' BLUE='' RED='' BOLD='' NC=''
fi

info() { printf '%b\n' "${BLUE}->  ${NC}$1"; }
ok()   { printf '%b\n' "${GREEN}[ok]${NC} $1"; }
err()  { printf '%b\n' "${RED}[x] ${NC}$1" >&2; }
die()  { err "$1"; exit 1; }

# ─── Paths ────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
VERSION_FILE="${REPO_ROOT}/VERSION"
CHANGELOG="${REPO_ROOT}/CHANGELOG.md"
README="${REPO_ROOT}/README.md"

# ─── Argument parsing ─────────────────────────────────────────────────────────

BUMP_OVERRIDE=""
for arg in "$@"; do
    case "$arg" in
        major|minor|patch) BUMP_OVERRIDE="$arg" ;;
        *) die "Unknown argument: $arg. Valid: major, minor, patch" ;;
    esac
done

# ─── Pre-checks ──────────────────────────────────────────────────────────────

info "Pre-checks..."

CURRENT_BRANCH="$(git -C "${REPO_ROOT}" rev-parse --abbrev-ref HEAD)"

# Must be on a feature/release branch, NOT main (we merge INTO main)
if [ "${CURRENT_BRANCH}" = "main" ]; then
    die "Cannot release from main. Switch to your feature/release branch first."
fi
ok "On branch: ${CURRENT_BRANCH}"

if [ -n "$(git -C "${REPO_ROOT}" status --porcelain)" ]; then
    die "Working tree is not clean. Commit or stash your changes first."
fi
ok "Working tree is clean"

if ! command -v python3 >/dev/null 2>&1; then
    die "python3 is required but not found"
fi

if ! gh auth status >/dev/null 2>&1; then
    die "GitHub CLI not authenticated. Run: gh auth login"
fi
ok "gh CLI authenticated"

# Make sure main is up to date
git -C "${REPO_ROOT}" fetch origin main
ok "Fetched origin/main"

LAST_TAG="$(git -C "${REPO_ROOT}" describe --tags --abbrev=0 2>/dev/null || echo "")"
if [ -z "${LAST_TAG}" ]; then
    die "No git tags found. Create an initial tag first."
fi
ok "Last tag: ${LAST_TAG}"

CURRENT_VERSION="$(cat "${VERSION_FILE}")"
ok "Current version: ${CURRENT_VERSION}"

# ─── Version calculation ─────────────────────────────────────────────────────

info "Calculating version bump..."

COMMITS="$(git -C "${REPO_ROOT}" log "${LAST_TAG}..HEAD" --pretty=format:"%s%n%b" 2>/dev/null || echo "")"
if [ -z "${COMMITS}" ]; then
    die "No commits since last tag ${LAST_TAG}. Nothing to release."
fi

BUMP="patch"
if echo "${COMMITS}" | grep -qE "(BREAKING CHANGE|^[a-z]+(\([^)]+\))?!:)"; then
    BUMP="major"
elif echo "${COMMITS}" | grep -qE "^feat(\([^)]+\))?:"; then
    BUMP="minor"
fi

if [ -n "${BUMP_OVERRIDE}" ]; then
    BUMP="${BUMP_OVERRIDE}"
    info "Bump level overridden: ${BUMP}"
fi

IFS='.' read -r MAJOR MINOR PATCH <<< "${CURRENT_VERSION}"
case "${BUMP}" in
    major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
    minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
    patch) PATCH=$((PATCH + 1)) ;;
esac
NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
ok "New version: ${NEW_VERSION} (${BUMP})"

# ─── File updates ────────────────────────────────────────────────────────────

info "Updating files..."
TODAY="$(date +%Y-%m-%d)"

# Collect and classify commits
COMMIT_LOG="$(git -C "${REPO_ROOT}" log "${LAST_TAG}..HEAD" --pretty=format:"COMMIT_SEP%n%s%n%b" 2>/dev/null)"
ADDED="" CHANGED="" FIXED="" OTHER=""

while IFS= read -r line; do
    [[ "$line" == "COMMIT_SEP" ]] && continue
    [[ -z "$line" ]] && continue
    if echo "$line" | grep -qE "^[a-z]+(\([^)]+\))?!?:"; then
        desc="$(echo "$line" | sed 's/^[a-z]*([^)]*): //' | sed 's/^[a-z]*!: //' | sed 's/^[a-z]*: //')"
        prefix="$(echo "$line" | grep -oE "^[a-z]+(\([^)]+\))?!?" | sed 's/([^)]*)//' | sed 's/!//')"
        case "$prefix" in
            feat)     ADDED="${ADDED}- ${desc}\n" ;;
            fix)      FIXED="${FIXED}- ${desc}\n" ;;
            refactor|chore|perf|style|ci|test|docs|build) CHANGED="${CHANGED}- ${desc}\n" ;;
            *)        OTHER="${OTHER}- ${desc}\n" ;;
        esac
    fi
done <<< "${COMMIT_LOG}"

NEW_ENTRY="## [${NEW_VERSION}] - ${TODAY}"$'\n'
[ -n "${ADDED}" ]   && NEW_ENTRY="${NEW_ENTRY}"$'\n'"### Added"$'\n\n'"$(printf '%b' "${ADDED}")"
[ -n "${CHANGED}" ] && NEW_ENTRY="${NEW_ENTRY}"$'\n'"### Changed"$'\n\n'"$(printf '%b' "${CHANGED}")"
[ -n "${FIXED}" ]   && NEW_ENTRY="${NEW_ENTRY}"$'\n'"### Fixed"$'\n\n'"$(printf '%b' "${FIXED}")"
[ -n "${OTHER}" ]   && NEW_ENTRY="${NEW_ENTRY}"$'\n'"### Other"$'\n\n'"$(printf '%b' "${OTHER}")"

# -- VERSION
printf '%s\n' "${NEW_VERSION}" > "${VERSION_FILE}"
ok "VERSION: ${NEW_VERSION}"

# -- CHANGELOG.md
FORGE_CHANGELOG="${CHANGELOG}" \
FORGE_NEW_ENTRY="${NEW_ENTRY}" \
FORGE_NEW_VERSION="${NEW_VERSION}" \
python3 - <<'PYEOF'
import os

changelog_path = os.environ["FORGE_CHANGELOG"]
new_entry = os.environ["FORGE_NEW_ENTRY"]
new_version = os.environ["FORGE_NEW_VERSION"]
new_link = f"[{new_version}]: https://github.com/fwehrling/forge/releases/tag/v{new_version}"

with open(changelog_path, 'r') as f:
    lines = f.readlines()

insert_pos = 7
link_insert_pos = None
for i, line in enumerate(lines):
    stripped = line.strip()
    if stripped.startswith('[') and ']: https://github.com/fwehrling/forge/releases/tag/' in stripped:
        link_insert_pos = i
        break

lines.insert(insert_pos, new_entry + "\n")

if link_insert_pos is not None:
    lines.insert(link_insert_pos + 1, new_link + "\n")
else:
    lines.append(new_link + "\n")

with open(changelog_path, 'w') as f:
    f.writelines(lines)
PYEOF
ok "CHANGELOG.md"

# -- README.md (badge + Latest line)
sed -i '' "s/version-[0-9]*\.[0-9]*\.[0-9]*-green/version-${NEW_VERSION}-green/g" "${README}"
sed -i '' "s/\*\*Latest -- v[0-9]*\.[0-9]*\.[0-9]*\*\*:/**Latest -- v${NEW_VERSION}**:/" "${README}"
ok "README.md (badge + latest)"

# ─── Commit, merge to main, push ─────────────────────────────────────────────

info "Committing and merging to main..."

git -C "${REPO_ROOT}" add "${VERSION_FILE}" "${CHANGELOG}" "${README}"
git -C "${REPO_ROOT}" add -u
git -C "${REPO_ROOT}" commit -m "chore: release v${NEW_VERSION}"
ok "Committed: chore: release v${NEW_VERSION}"

# Push current branch
git -C "${REPO_ROOT}" push -u origin "${CURRENT_BRANCH}"
ok "Pushed ${CURRENT_BRANCH}"

# Switch to main, rebase, push
git -C "${REPO_ROOT}" checkout main
git -C "${REPO_ROOT}" pull --rebase origin main
git -C "${REPO_ROOT}" rebase "${CURRENT_BRANCH}"
git -C "${REPO_ROOT}" push origin main
ok "Merged to main and pushed"

# Go back to the branch
git -C "${REPO_ROOT}" checkout "${CURRENT_BRANCH}"

# ─── Summary ─────────────────────────────────────────────────────────────────

printf '\n'
printf '%b\n' "${BOLD}=== FORGE Release Complete ===${NC}"
printf '%b\n' "  ${CURRENT_VERSION} -> ${GREEN}${NEW_VERSION}${NC} (${BUMP})"
printf '%b\n' "  main is up to date on origin"
printf '%b\n' "  No tag created -- no deployment triggered"
printf '\n'
printf '%b\n' "Next step: ${YELLOW}/forge:ship${NC} to tag and deploy"
