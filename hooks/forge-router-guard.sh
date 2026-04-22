#!/usr/bin/env bash
# FORGE Router Guard -- UserPromptSubmit hook (v1.14.0+)
#
# Opposite design to the removed v1.9.0 forge-router-reminder.sh:
# - v1.9.0 triggered on EVERY non-/forge prompt in a FORGE project (expensive: ~200 tok x N prompts)
# - v1.14 triggers ONLY when the prompt looks like a FORGE request without the slash
#   (regex: ^\s*forge(-[a-z-]+)?\b). Zero tokens on neutral prompts.
#
# Match examples (injects a soft reminder):
#   "forge auto build the landing page"   -> reminder
#   "forge-debug this crash"               -> reminder
#   "forge improve the auth module"        -> reminder
#
# No-match examples (silent, 0 token):
#   "/forge build X"                        -> handled by /forge slash-command
#   "explain this function"                 -> neutral, no reminder
#   "il faut forger un plan"                -> 'forge' not at start of line
#   "the blacksmith forges steel"           -> not start of line
#
# Always exits 0 (never blocks prompt submission).

input=$(cat)

PROMPT=$(printf '%s' "$input" | jq -r '.prompt // ""' 2>/dev/null)
[ -z "$PROMPT" ] && exit 0

# Skip if already a slash-command (handled by slash-command resolver or other hooks)
if printf '%s' "$PROMPT" | grep -qE '^\s*/'; then
    exit 0
fi

# Match only if first non-whitespace word is 'forge' or 'forge-<something>'
if printf '%s' "$PROMPT" | grep -qiE '^\s*forge(-[a-z-]+)?\b'; then
    echo "If this is a FORGE request, invoke the \`forge\` skill via the Skill tool to route through the hub (intent classification + HITL gates). If the request is unrelated, ignore this hint."
fi

exit 0
