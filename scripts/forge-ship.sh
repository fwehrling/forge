#!/usr/bin/env bash
# FORGE — Prepare a release: bump version, update CHANGELOG, README, and optionally finalize
# Usage:
#   forge-ship.sh                     # auto-detect bump level, dry-run summary
#   forge-ship.sh major|minor|patch   # override bump level
#   forge-ship.sh finalize            # auto-detect bump + finalize (branch, commit, PR)
#   forge-ship.sh minor finalize      # override bump + finalize
set -euo pipefail

# ─── Colors ───────────────────────────────────────────────────────────────────

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

info()  { printf '%b\n' "${BLUE}->  ${NC}$1"; }
ok()    { printf '%b\n' "${GREEN}[ok]${NC} $1"; }
warn()  { printf '%b\n' "${YELLOW}[!] ${NC}$1"; }
err()   { printf '%b\n' "${RED}[x] ${NC}$1" >&2; }
die()   { err "$1"; exit 1; }

# ─── Paths ────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
VERSION_FILE="${REPO_ROOT}/VERSION"
CHANGELOG="${REPO_ROOT}/CHANGELOG.md"
README="${REPO_ROOT}/README.md"

# ─── Argument parsing ─────────────────────────────────────────────────────────

BUMP_OVERRIDE=""
FINALIZE=false

for arg in "$@"; do
    case "$arg" in
        finalize) FINALIZE=true ;;
        major|minor|patch) BUMP_OVERRIDE="$arg" ;;
        *) die "Unknown argument: $arg. Valid: major, minor, patch, finalize" ;;
    esac
done

# ─── Phase 1: Pre-checks ──────────────────────────────────────────────────────

info "Phase 1: Pre-checks..."

# Verify working tree is clean (skip when finalizing -- files were modified by prior run)
if [ "${FINALIZE}" = "false" ]; then
    if [ -n "$(git -C "${REPO_ROOT}" status --porcelain)" ]; then
        die "Working tree is not clean. Commit or stash your changes first."
    fi
    ok "Working tree is clean"
fi

# Verify current branch is main
CURRENT_BRANCH="$(git -C "${REPO_ROOT}" rev-parse --abbrev-ref HEAD)"
if [ "${CURRENT_BRANCH}" != "main" ]; then
    die "Must be on branch 'main', currently on '${CURRENT_BRANCH}'"
fi
ok "On branch main"

# Verify python3 is available (used for CHANGELOG generation)
if ! command -v python3 >/dev/null 2>&1; then
    die "python3 is required but not found"
fi

# Verify gh CLI is authenticated
if ! gh auth status >/dev/null 2>&1; then
    die "GitHub CLI not authenticated. Run: gh auth login"
fi
ok "gh CLI authenticated"

# Get last tag
LAST_TAG="$(git -C "${REPO_ROOT}" describe --tags --abbrev=0 2>/dev/null || echo "")"
if [ -z "${LAST_TAG}" ]; then
    die "No git tags found. Create an initial tag first."
fi
ok "Last tag: ${LAST_TAG}"

# Read current version
CURRENT_VERSION="$(cat "${VERSION_FILE}")"
ok "Current version: ${CURRENT_VERSION}"

# ─── Phase 2: Version calculation ─────────────────────────────────────────────

info "Phase 2: Calculating version bump..."

# List commits since last tag
COMMITS="$(git -C "${REPO_ROOT}" log "${LAST_TAG}..HEAD" --pretty=format:"%s%n%b" 2>/dev/null || echo "")"

if [ -z "${COMMITS}" ]; then
    die "No commits since last tag ${LAST_TAG}. Nothing to release."
fi

# Determine bump level from Conventional Commits
BUMP="patch"

# Check for BREAKING CHANGE in body or '!' before ':' in header
if echo "${COMMITS}" | grep -qE "(BREAKING CHANGE|^[a-z]+(\([^)]+\))?!:)"; then
    BUMP="major"
elif echo "${COMMITS}" | grep -qE "^feat(\([^)]+\))?:"; then
    BUMP="minor"
fi

# Allow override via argument
if [ -n "${BUMP_OVERRIDE}" ]; then
    BUMP="${BUMP_OVERRIDE}"
    info "Bump level overridden: ${BUMP}"
else
    info "Detected bump level: ${BUMP}"
fi

ok "Bump: ${BUMP}"

# Calculate new version
IFS='.' read -r MAJOR MINOR PATCH <<< "${CURRENT_VERSION}"
case "${BUMP}" in
    major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
    minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
    patch) PATCH=$((PATCH + 1)) ;;
esac
NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
ok "New version: ${NEW_VERSION}"

# ─── Phase 3: File updates ────────────────────────────────────────────────────

info "Phase 3: Updating files..."

TODAY="$(date +%Y-%m-%d)"

# Collect commits since last tag (with full subject + body for classification)
COMMIT_LOG="$(git -C "${REPO_ROOT}" log "${LAST_TAG}..HEAD" --pretty=format:"COMMIT_SEP%n%s%n%b" 2>/dev/null)"

# Build grouped changelog entry
ADDED=""
CHANGED=""
FIXED=""
OTHER=""

# Process each commit: extract subject line and classify
while IFS= read -r line; do
    # Skip separator and empty lines
    [[ "$line" == "COMMIT_SEP" ]] && continue
    [[ -z "$line" ]] && continue

    # Only process subject lines (Conventional Commits format)
    if echo "$line" | grep -qE "^[a-z]+(\([^)]+\))?!?:"; then
        # Extract the description part after the colon
        desc="$(echo "$line" | sed 's/^[a-z]*([^)]*): //' | sed 's/^[a-z]*!: //' | sed 's/^[a-z]*: //')"
        prefix="$(echo "$line" | grep -oE "^[a-z]+(\([^)]+\))?!?" | sed 's/([^)]*)//' | sed 's/!//')"

        case "$prefix" in
            feat)
                ADDED="${ADDED}- ${desc}\n"
                ;;
            fix)
                FIXED="${FIXED}- ${desc}\n"
                ;;
            refactor|chore|perf|style|ci|test|docs|build)
                CHANGED="${CHANGED}- ${desc}\n"
                ;;
            *)
                OTHER="${OTHER}- ${desc}\n"
                ;;
        esac
    fi
done <<< "${COMMIT_LOG}"

# Build the new changelog entry
NEW_ENTRY="## [${NEW_VERSION}] - ${TODAY}"$'\n'

if [ -n "${ADDED}" ]; then
    NEW_ENTRY="${NEW_ENTRY}"$'\n'"### Added"$'\n\n'
    NEW_ENTRY="${NEW_ENTRY}$(printf '%b' "${ADDED}")"
fi
if [ -n "${CHANGED}" ]; then
    NEW_ENTRY="${NEW_ENTRY}"$'\n'"### Changed"$'\n\n'
    NEW_ENTRY="${NEW_ENTRY}$(printf '%b' "${CHANGED}")"
fi
if [ -n "${FIXED}" ]; then
    NEW_ENTRY="${NEW_ENTRY}"$'\n'"### Fixed"$'\n\n'
    NEW_ENTRY="${NEW_ENTRY}$(printf '%b' "${FIXED}")"
fi
if [ -n "${OTHER}" ]; then
    NEW_ENTRY="${NEW_ENTRY}"$'\n'"### Other"$'\n\n'
    NEW_ENTRY="${NEW_ENTRY}$(printf '%b' "${OTHER}")"
fi

# ── VERSION ──────────────────────────────────────────────────────────────────
printf '%s\n' "${NEW_VERSION}" > "${VERSION_FILE}"
ok "Updated VERSION: ${NEW_VERSION}"

# ── CHANGELOG.md ─────────────────────────────────────────────────────────────
# Header is 7 lines; new entry goes after line 7 (insert after the blank line at line 7)
# Strategy: use Python for reliable multi-line insertion on both macOS and Linux
# Pass data via env vars to avoid shell injection in heredoc
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

# Insert new entry after line 7 (index 7, i.e. after the blank line)
insert_pos = 7
# Find the first release link line to insert the new link before it
link_insert_pos = None
for i, line in enumerate(lines):
    stripped = line.strip()
    if stripped.startswith('[') and ']: https://github.com/fwehrling/forge/releases/tag/' in stripped:
        link_insert_pos = i
        break

# Insert the entry block
entry_block = new_entry + "\n"
lines.insert(insert_pos, entry_block)

# Recalculate link position (shifted by inserted block)
if link_insert_pos is not None:
    link_insert_pos += 1  # shifted by 1 due to insertion
    lines.insert(link_insert_pos, new_link + "\n")
else:
    lines.append(new_link + "\n")

with open(changelog_path, 'w') as f:
    f.writelines(lines)

print("ok")
PYEOF
ok "Updated CHANGELOG.md"

# ── README.md ─────────────────────────────────────────────────────────────────
# Update badge on line 5: version-X.Y.Z-green
sed -i '' "s/version-${CURRENT_VERSION}-green/version-${NEW_VERSION}-green/g" "${README}"

# Update "Latest" line
sed -i '' "s/\*\*Latest -- v[0-9]*\.[0-9]*\.[0-9]*\*\*:/**Latest -- v${NEW_VERSION}**:/" "${README}"
ok "Updated README.md"

# ─── Summary output ───────────────────────────────────────────────────────────

printf '\n'
printf '%b\n' "${BOLD}=== FORGE Release Summary ===${NC}"
printf '%b\n' "  Previous version : ${YELLOW}${CURRENT_VERSION}${NC}"
printf '%b\n' "  New version      : ${GREEN}${NEW_VERSION}${NC}"
printf '%b\n' "  Bump level       : ${BUMP}"
printf '%b\n' "  Branch target    : release/v${NEW_VERSION}"
printf '\n'
printf '%b\n' "${BOLD}Files modified:${NC}"
printf '  %s\n' "VERSION" "CHANGELOG.md" "README.md"
printf '\n'

# ─── Phase 5: Finalize (optional) ────────────────────────────────────────────

finalize() {
    info "Phase 5: Finalizing release v${NEW_VERSION}..."

    BRANCH="release/v${NEW_VERSION}"

    # Create branch
    git -C "${REPO_ROOT}" checkout -b "${BRANCH}"
    ok "Created branch: ${BRANCH}"

    # Stage modified files (including any README changes made by Claude)
    git -C "${REPO_ROOT}" add "${VERSION_FILE}" "${CHANGELOG}" "${README}"
    git -C "${REPO_ROOT}" add -u
    ok "Staged: VERSION, CHANGELOG.md, README.md (+ any other modified files)"

    # Commit
    git -C "${REPO_ROOT}" commit -m "chore: release v${NEW_VERSION}"
    ok "Committed: chore: release v${NEW_VERSION}"

    # Push branch
    git -C "${REPO_ROOT}" push -u origin "${BRANCH}"
    ok "Pushed branch: ${BRANCH}"

    # Create PR
    PR_BODY="## Release v${NEW_VERSION}

Bump: ${BUMP}

### Changes included
$(git -C "${REPO_ROOT}" log "${LAST_TAG}..HEAD~1" --pretty=format:"- %s" 2>/dev/null || echo "- see CHANGELOG.md")

---
*Generated by forge-ship.sh*"

    PR_URL="$(gh pr create \
        --repo fwehrling/forge \
        --base main \
        --head "${BRANCH}" \
        --title "chore: release v${NEW_VERSION}" \
        --body "${PR_BODY}")"

    ok "PR created: ${PR_URL}"
    printf '\n'
    printf '%b\n' "${GREEN}${BOLD}Release v${NEW_VERSION} is ready for review!${NC}"
    printf '%b\n' "  PR: ${PR_URL}"
}

if [ "${FINALIZE}" = "true" ]; then
    finalize
else
    printf '%b\n' "${YELLOW}[dry-run]${NC} Files updated locally. Run with 'finalize' argument to create branch, commit, and PR."
    printf '%b\n' "  Example: bash scripts/forge-ship.sh ${BUMP} finalize"
fi
