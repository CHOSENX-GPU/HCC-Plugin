#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/util/platform.sh"

# Read stdin JSON (Stop hook receives stop_hook_active + last_assistant_message)
INPUT=""
if [[ ! -t 0 ]]; then
  INPUT=$(cat)
fi

# Extract stop_hook_active (prevent infinite loops per Claude Code docs)
STOP_ACTIVE="false"
LAST_MSG=""
if [[ -n "$INPUT" ]] && command -v jq &>/dev/null; then
  STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
  LAST_MSG=$(echo "$INPUT" | jq -r '.last_assistant_message // ""' 2>/dev/null | tail -c 1000)
fi

PROJECT_DIR="$(_project_root "$(pwd)")" || exit 0
[[ ! -d "$PROJECT_DIR/memory" ]] && exit 0
[[ ! -f "$PROJECT_DIR/memory/trace.md" ]] && exit 0

TICKS="$PROJECT_DIR/.hcc/action_ticks"
CONFIG="$PROJECT_DIR/.hcc/config.yaml"

# Read count from the atomic ticks file (source of truth)
if [[ -f "$TICKS" ]]; then
  COUNT=$(wc -l < "$TICKS" | tr -d ' ')
else
  COUNT=0
fi

# --- TURN marker (always written, regardless of gate) ---
LAST_TURN_FILE="$PROJECT_DIR/.hcc/last_turn_count.tmp"
LAST_TURN=$(cat "$LAST_TURN_FILE" 2>/dev/null || echo "0")
if [[ "$COUNT" -ne "$LAST_TURN" ]]; then
  echo "$COUNT" > "$LAST_TURN_FILE"
  HCC_NO_INCREMENT=1 bash "$SCRIPT_DIR/log-trace.sh" "$PROJECT_DIR" \
    --phase turn "${COUNT} actions this turn"
fi

# --- Gate logic: only runs when stop_hook_active is false ---
if [[ "$STOP_ACTIVE" == "true" ]]; then
  exit 0
fi

# Check for active task
ACTIVE="$PROJECT_DIR/memory/tasks/_active.md"
[[ ! -f "$ACTIVE" ]] && exit 0

source "$SCRIPT_DIR/util/frontmatter.sh"
TASK_STATUS=$(_fm_get "$ACTIVE" "status")
[[ "$TASK_STATUS" != "active" ]] && exit 0

# --- Promote gate ---
PROMOTE_THRESHOLD=$(grep "promote_threshold:" "$CONFIG" 2>/dev/null | awk '{print $2}')
PROMOTE_THRESHOLD=${PROMOTE_THRESHOLD:-15}

LAST_PROMOTE_FILE="$PROJECT_DIR/.hcc/last_promote_count.tmp"
LAST_PROMOTE=$(cat "$LAST_PROMOTE_FILE" 2>/dev/null || echo "0")
LAST_PROMOTE=$(echo "$LAST_PROMOTE" | tr -d '[:space:]')
LAST_PROMOTE=${LAST_PROMOTE:-0}

SINCE_PROMOTE=$((COUNT - LAST_PROMOTE))

if [[ "$SINCE_PROMOTE" -ge "$PROMOTE_THRESHOLD" ]]; then
  echo "$COUNT" > "$LAST_PROMOTE_FILE"
  echo '{"decision":"block","reason":"[HCC Memory] You have accumulated '"$SINCE_PROMOTE"' actions since your last findings extraction. Run /hcc-memory:promote to distill findings from your recent work, then continue your task."}'
  exit 0
fi

# --- Complete gate ---
COMPLETE_FLAG="$PROJECT_DIR/.hcc/complete_requested.tmp"
[[ -f "$COMPLETE_FLAG" ]] && exit 0

COMPLETION_PATTERN='(completed|finished|all done|all tasks|wrapped up|summary of|in summary|完成|已完成|总结|全部完成|任务完成|all.*complete)'
if echo "$LAST_MSG" | grep -iqE "$COMPLETION_PATTERN"; then
  touch "$COMPLETE_FLAG"
  TASK_NAME=$(_fm_get "$ACTIVE" "task")
  echo '{"decision":"block","reason":"[HCC Memory] Your task appears complete. Run /hcc-memory:promote to save any remaining findings, then run /hcc-memory:complete '\''<brief summary>'\'' to archive your trace and properly close the task: '"$TASK_NAME"'"}'
  exit 0
fi

exit 0
