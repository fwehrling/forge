#!/usr/bin/env bash
# FORGE Update Check — SessionStart hook
# Silently checks if a newer FORGE version is available (max 1x per 24h).
# Outputs a notification string if update available, empty otherwise.
# Always exits 0 (never blocks session startup).

set -euo pipefail

LOCAL_VERSION_FILE="${HOME}/.claude/skills/forge/.forge-version"
CACHE_FILE="${HOME}/.claude/skills/forge/.forge-update-cache"
REMOTE_URL="https://raw.githubusercontent.com/fwehrling/forge/main/VERSION"
TTL=86400  # 24 hours in seconds

# Not installed — skip silently
if [ ! -f "$LOCAL_VERSION_FILE" ]; then
    exit 0
fi

# Check cache TTL
if [ -f "$CACHE_FILE" ]; then
    cache_ts=$(head -1 "$CACHE_FILE" 2>/dev/null || echo "0")
    now=$(date +%s)
    elapsed=$(( now - cache_ts ))
    if [ "$elapsed" -lt "$TTL" ]; then
        # Cache still fresh — print cached notification if any
        cached_msg=$(tail -n +2 "$CACHE_FILE" 2>/dev/null || true)
        if [ -n "$cached_msg" ]; then
            echo "$cached_msg"
        fi
        exit 0
    fi
fi

# Fetch remote version (timeout 3s)
remote_version=$(curl -s --max-time 3 "$REMOTE_URL" 2>/dev/null | tr -d '[:space:]') || true

# Validate: must be non-empty and look like semver (e.g. 1.2.3)
if [ -z "$remote_version" ] || ! echo "$remote_version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+'; then
    exit 0
fi

local_version=$(tr -d '[:space:]' < "$LOCAL_VERSION_FILE")

# Compare versions
now=$(date +%s)
if [ "$local_version" != "$remote_version" ]; then
    msg="FORGE update available (v${local_version} → v${remote_version}). Run /forge-update to update."
    # Write cache with notification
    printf '%s\n%s\n' "$now" "$msg" > "$CACHE_FILE"
    echo "$msg"
else
    # Write cache without notification (versions match)
    printf '%s\n' "$now" > "$CACHE_FILE"
fi

exit 0
