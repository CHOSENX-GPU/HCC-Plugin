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
TICKS="$PROJECT_DIR/.hcc/action_ticks"

[[ ! -d "$PROJECT_DIR/memory" ]] && exit 0
[[ ! -f "$STATE" ]] && exit 0

# Bug 3 fix: if plan.sh just ran, skip this invocation so the plan
# command itself is not counted as an action.
SKIP_FLAG="$PROJECT_DIR/.hcc/skip_next_count"
if [[ -f "$SKIP_FLAG" ]]; then
  rm -f "$SKIP_FLAG"
  exit 0
fi

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

# Bug 1 fix: atomic append instead of read-modify-write.
# echo >> file is atomic for short writes on POSIX, so concurrent hooks
# each append exactly one line and no increment is ever lost.
echo "${TOOL_BRIEF:-+}" >> "$TICKS"

# Count = number of lines (always accurate regardless of concurrency)
COUNT=$(wc -l < "$TICKS" | tr -d ' ')

# Best-effort sync to state.json for display consumers (non-critical race is OK)
_json_set "$STATE" "action_count" "$COUNT" 2>/dev/null || true

# Read flush interval from config
INTERVAL=$(grep "flush_interval:" "$CONFIG" 2>/dev/null | awk '{print $2}')
INTERVAL=${INTERVAL:-5}

# Checkpoint decision: use (COUNT - LAST_CP) >= INTERVAL so that even if
# a modulo boundary is skipped due to concurrency, the next process catches it.
LAST_CP_FILE="$PROJECT_DIR/.hcc/last_checkpoint.tmp"
LAST_CP=$(cat "$LAST_CP_FILE" 2>/dev/null || echo "0")
LAST_CP=$(echo "$LAST_CP" | tr -d '[:space:]')
LAST_CP=${LAST_CP:-0}

if [[ $((COUNT - LAST_CP)) -ge $INTERVAL && -f "$PROJECT_DIR/memory/trace.md" ]]; then
  # Acquire portable lock (mkdir is atomic on all POSIX systems)
  LOCK="$PROJECT_DIR/.hcc/checkpoint.lock"
  if mkdir "$LOCK" 2>/dev/null; then
    trap 'rmdir "'"$LOCK"'" 2>/dev/null || true' EXIT

    # Re-verify inside lock (another process may have written the checkpoint)
    COUNT=$(wc -l < "$TICKS" | tr -d ' ')
    LAST_CP=$(cat "$LAST_CP_FILE" 2>/dev/null || echo "0")
    LAST_CP=$(echo "$LAST_CP" | tr -d '[:space:]')
    LAST_CP=${LAST_CP:-0}

    if [[ $((COUNT - LAST_CP)) -ge $INTERVAL ]]; then
      RANGE_START=$((LAST_CP + 1))

      # Extract activity for this checkpoint range from the ticks file
      ACTIVITY=$(tail -n "+${RANGE_START}" "$TICKS" | head -n "$((COUNT - LAST_CP))")

      echo "$ACTIVITY" | HCC_NO_INCREMENT=1 bash "$SCRIPT_DIR/log-trace.sh" \
        "$PROJECT_DIR" --phase checkpoint "Actions ${RANGE_START}-${COUNT}"

      echo "$COUNT" > "$LAST_CP_FILE"
      _json_set "$STATE" "action_count" "$COUNT" 2>/dev/null || true
    fi

    rmdir "$LOCK" 2>/dev/null || true
    trap - EXIT
  fi
  # If mkdir failed, another process is handling the checkpoint -- skip
fi
