#!/usr/bin/env bash
# rtk-native-hook.sh - PreToolUse hook: compresses Read/Grep/Glob via RTK
#
# Protocol: receives JSON on stdin, returns JSON on stdout
# - permissionDecision "deny" + reason = blocked, Claude gets compressed content
# - exit 0 no output = pass through (small files, errors)
#
# Thresholds (tune as needed):
READ_THRESHOLD=80     # lines - below this, Read passes through
GREP_THRESHOLD=50     # result lines - below this, Grep passes through
GLOB_THRESHOLD=30     # entries - below this, Glob passes through

set -euo pipefail

# Hard dependencies
if ! command -v jq &>/dev/null || ! command -v rtk &>/dev/null; then
  exit 0
fi

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // empty')

deny_with_content() {
  local header="$1"
  local content="$2"
  jq -n \
    --arg reason "$header"$'\n\n'"$content" \
    '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: $reason
      }
    }'
  exit 0
}

case "$tool_name" in

  Read)
    file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')
    [[ -z "$file_path" || ! -f "$file_path" ]] && exit 0

    # Only compress source code files where RTK provides real savings
    # Skip: .sh .bash .md .json .yaml .yml .toml .env .lock .txt .csv
    case "${file_path##*.}" in
      ts|tsx|js|jsx|mjs|cjs|py|rb|java|go|rs|cpp|c|h|cs|swift|kt|php|vue|svelte) ;;
      *) exit 0 ;;
    esac

    line_count=$(wc -l < "$file_path" 2>/dev/null || echo 0)
    [[ "$line_count" -lt "$READ_THRESHOLD" ]] && exit 0

    compressed=$(rtk read "$file_path" -l aggressive 2>/dev/null) || exit 0
    compressed_lines=$(echo "$compressed" | wc -l)
    savings=$(( (line_count - compressed_lines) * 100 / line_count ))

    deny_with_content \
      "[RTK:Read] $file_path -- ${line_count}L -> ${compressed_lines}L (${savings}% saved)" \
      "$compressed"
    ;;

  Grep)
    pattern=$(echo "$input" | jq -r '.tool_input.pattern // empty')
    search_path=$(echo "$input" | jq -r '.tool_input.path // "."')
    [[ -z "$pattern" ]] && exit 0

    compressed=$(rtk grep "$pattern" "$search_path" 2>/dev/null) || exit 0
    result_lines=$(echo "$compressed" | wc -l)
    [[ "$result_lines" -lt "$GREP_THRESHOLD" ]] && exit 0

    deny_with_content \
      "[RTK:Grep] pattern='$pattern' path=$search_path -- ${result_lines}L compressed" \
      "$compressed"
    ;;

  Glob)
    pattern=$(echo "$input" | jq -r '.tool_input.pattern // empty')
    glob_path=$(echo "$input" | jq -r '.tool_input.path // "."')
    [[ -z "$pattern" ]] && exit 0

    compressed=$(rtk find "$pattern" "$glob_path" 2>/dev/null) || exit 0
    result_lines=$(echo "$compressed" | wc -l)
    [[ "$result_lines" -lt "$GLOB_THRESHOLD" ]] && exit 0

    deny_with_content \
      "[RTK:Glob] pattern='$pattern' path=$glob_path -- ${result_lines} entries" \
      "$compressed"
    ;;

  *)
    exit 0
    ;;
esac
