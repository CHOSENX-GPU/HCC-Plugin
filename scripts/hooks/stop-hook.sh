#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/util/platform.sh"

# Read stdin JSON
INPUT=""
if [[ ! -t 0 ]]; then
  INPUT=$(cat)
fi

# CRITICAL: check stop_hook_active to prevent infinite loops (per Claude Code docs)
if [[ -n "$INPUT" ]] && command -v jq &>/dev/null; then
  if [ "$(echo "$INPUT" | jq -r '.stop_hook_active // false')" = "true" ]; then
    exit 0
  fi
fi

PROJECT_DIR="$(_project_root "$(pwd)")" || exit 0
[[ ! -d "$PROJECT_DIR/memory" ]] && exit 0
[[ ! -f "$PROJECT_DIR/memory/trace.md" ]] && exit 0

STATE="$PROJECT_DIR/.hcc/state.json"
[[ ! -f "$STATE" ]] && exit 0

COUNT=$(_json_get "$STATE" "action_count")
COUNT=${COUNT:-0}

# Avoid duplicate turn markers for idle turns
LAST_TURN_FILE="$PROJECT_DIR/.hcc/last_turn_count.tmp"
LAST_TURN=$(cat "$LAST_TURN_FILE" 2>/dev/null || echo "0")
[[ "$COUNT" -eq "$LAST_TURN" ]] && exit 0

echo "$COUNT" > "$LAST_TURN_FILE"
HCC_NO_INCREMENT=1 bash "$SCRIPT_DIR/log-trace.sh" "$PROJECT_DIR" \
  --phase turn "${COUNT} actions this turn"
