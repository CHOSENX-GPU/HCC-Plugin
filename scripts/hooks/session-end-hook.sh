#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/util/platform.sh"

PROJECT_DIR="$(_project_root "$(pwd)")" || exit 0
[[ ! -d "$PROJECT_DIR/memory" ]] && exit 0
[[ ! -f "$PROJECT_DIR/memory/trace.md" ]] && exit 0

STATE="$PROJECT_DIR/.hcc/state.json"
[[ ! -f "$STATE" ]] && exit 0

COUNT=$(_json_get "$STATE" "action_count")
COUNT=${COUNT:-0}
[[ "$COUNT" -eq 0 ]] && exit 0

# Flush any remaining tool activity as a final checkpoint
ACTIVITY_FILE="$PROJECT_DIR/.hcc/tool_activity.tmp"
if [[ -f "$ACTIVITY_FILE" ]] && [[ -s "$ACTIVITY_FILE" ]]; then
  INTERVAL=$(grep "flush_interval:" "$PROJECT_DIR/.hcc/config.yaml" 2>/dev/null | awk '{print $2}')
  INTERVAL=${INTERVAL:-5}
  LAST_CHECKPOINT=$(( (COUNT / INTERVAL) * INTERVAL ))
  RANGE_START=$((LAST_CHECKPOINT + 1))
  if [[ "$RANGE_START" -le "$COUNT" ]]; then
    ACTIVITY=$(cat "$ACTIVITY_FILE" 2>/dev/null || true)
    echo "$ACTIVITY" | HCC_NO_INCREMENT=1 bash "$SCRIPT_DIR/log-trace.sh" \
      "$PROJECT_DIR" --phase checkpoint "Actions ${RANGE_START}-${COUNT}"
    > "$ACTIVITY_FILE"
  fi
fi

# Write session-end summary
HCC_NO_INCREMENT=1 bash "$SCRIPT_DIR/log-trace.sh" "$PROJECT_DIR" \
  --phase session_end "Total actions: ${COUNT}"
