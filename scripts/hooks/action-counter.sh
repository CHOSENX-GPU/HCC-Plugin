#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/util/platform.sh"

STATE="$PROJECT_DIR/.hcc/state.json"
CONFIG="$PROJECT_DIR/.hcc/config.yaml"

# Silently exit if no memory system
[[ ! -d "$PROJECT_DIR/memory" ]] && exit 0
[[ ! -f "$STATE" ]] && exit 0

# Read and increment counter
COUNT=$(_json_get "$STATE" "action_count")
COUNT=${COUNT:-0}
COUNT=$((COUNT + 1))
_json_set "$STATE" "action_count" "$COUNT"

# Read flush interval from config
INTERVAL=$(grep "flush_interval:" "$CONFIG" 2>/dev/null | awk '{print $2}')
INTERVAL=${INTERVAL:-5}

# Remind at interval
if [[ "$COUNT" -gt 0 && $((COUNT % INTERVAL)) -eq 0 ]]; then
  echo "⚠️ [HCC] 5-Action Rule: Time to update trace. Describe your recent work or run /hcc-memory:log."
fi
