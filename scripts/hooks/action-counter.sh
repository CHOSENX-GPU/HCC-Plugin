#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/util/platform.sh"

# Read stdin JSON from Claude Code hook system (PostToolUse passes tool info)
INPUT=""
if [[ ! -t 0 ]]; then
  INPUT=$(cat)
fi

# Resolve project root -- fixes the pwd bug where $(pwd) could be a subdirectory
CWD="$(pwd)"
if [[ -n "$INPUT" ]] && command -v jq &>/dev/null; then
  STDIN_CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
  [[ -n "$STDIN_CWD" ]] && CWD="$STDIN_CWD"
fi
PROJECT_DIR="$(_project_root "$CWD")" || exit 0

STATE="$PROJECT_DIR/.hcc/state.json"
CONFIG="$PROJECT_DIR/.hcc/config.yaml"

[[ ! -d "$PROJECT_DIR/memory" ]] && exit 0
[[ ! -f "$STATE" ]] && exit 0

# Extract tool info from stdin JSON for meaningful checkpoint content
TOOL_BRIEF=""
if [[ -n "$INPUT" ]] && command -v jq &>/dev/null; then
  TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
  case "$TOOL_NAME" in
    Write|Edit)
      FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // "?"')
      TOOL_BRIEF="- ${TOOL_NAME}: $(basename "$FILE_PATH")" ;;
    Bash)
      CMD=$(echo "$INPUT" | jq -r '.tool_input.command // "?"' | head -1 | cut -c1-60)
      TOOL_BRIEF="- Bash: ${CMD}" ;;
    *)
      TOOL_BRIEF="- ${TOOL_NAME}" ;;
  esac
elif [[ -n "$INPUT" ]]; then
  TOOL_NAME=$(echo "$INPUT" | grep -o '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | \
    head -1 | sed 's/.*:.*"//' | sed 's/"//')
  TOOL_BRIEF="- ${TOOL_NAME:-tool}"
fi

# Append tool activity to temp file for checkpoint aggregation
if [[ -n "$TOOL_BRIEF" ]]; then
  echo "$TOOL_BRIEF" >> "$PROJECT_DIR/.hcc/tool_activity.tmp"
fi

# Read and increment counter
COUNT=$(_json_get "$STATE" "action_count")
COUNT=${COUNT:-0}
COUNT=$((COUNT + 1))
_json_set "$STATE" "action_count" "$COUNT"

# Read flush interval from config
INTERVAL=$(grep "flush_interval:" "$CONFIG" 2>/dev/null | awk '{print $2}')
INTERVAL=${INTERVAL:-5}

# Auto-write checkpoint at interval
if [[ "$COUNT" -gt 0 && $((COUNT % INTERVAL)) -eq 0 ]]; then
  RANGE_START=$((COUNT - INTERVAL + 1))

  if [[ -f "$PROJECT_DIR/memory/trace.md" ]]; then
    ACTIVITY=$(cat "$PROJECT_DIR/.hcc/tool_activity.tmp" 2>/dev/null || true)
    echo "$ACTIVITY" | HCC_NO_INCREMENT=1 bash "$SCRIPT_DIR/log-trace.sh" \
      "$PROJECT_DIR" --phase checkpoint "Actions ${RANGE_START}-${COUNT}"
    > "$PROJECT_DIR/.hcc/tool_activity.tmp"
  fi

  echo "📝 [HCC] Auto-logged trace (actions ${RANGE_START}-${COUNT}). Add detail: /hcc-memory:log"
fi
