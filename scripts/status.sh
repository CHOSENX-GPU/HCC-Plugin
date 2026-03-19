#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/util/platform.sh"
source "$SCRIPT_DIR/util/frontmatter.sh"

PROJECT_DIR="$1"

if [[ ! -d "$PROJECT_DIR/memory" ]]; then
  echo "ERROR: memory/ not found. Run /hcc-memory:init first." >&2
  exit 1
fi

CONFIG="$PROJECT_DIR/.hcc/config.yaml"
STATE="$PROJECT_DIR/.hcc/state.json"
ACTIVE="$PROJECT_DIR/memory/tasks/_active.md"
TRACE="$PROJECT_DIR/memory/trace.md"

# Project info
PROJ_NAME=$(grep "name:" "$CONFIG" | head -1 | sed 's/.*name:[[:space:]]*//' | tr -d '"')
DOMAIN=$(grep "domain:" "$CONFIG" | head -1 | sed 's/.*domain:[[:space:]]*//' | tr -d '"')
INTERVAL=$(grep "flush_interval:" "$CONFIG" 2>/dev/null | awk '{print $2}')
INTERVAL=${INTERVAL:-5}

echo "=== HCC Memory Status ==="
echo "Project: $PROJ_NAME"
echo "Domain:  $DOMAIN"
echo ""

# Active task
if [[ -f "$ACTIVE" ]]; then
  TASK_STATUS=$(_fm_get "$ACTIVE" "status")
  if [[ "$TASK_STATUS" == "active" ]]; then
    TASK_NAME=$(_fm_get "$ACTIVE" "task")
    TASK_STARTED=$(_fm_get "$ACTIVE" "started_at")
    echo "Active Task: $TASK_NAME"
    echo "  Started: $TASK_STARTED"
  else
    echo "Active Task: none"
  fi
else
  echo "Active Task: none"
fi
echo ""

# Action counter
ACTION_COUNT=$(_json_get "$STATE" "action_count")
ACTION_COUNT=${ACTION_COUNT:-0}
echo "Action Count: $ACTION_COUNT (flush every $INTERVAL)"
echo ""

# Trace stats (count ## [ blocks)
if [[ -f "$TRACE" ]]; then
  TRACE_BLOCKS=$(grep -c "^## \[" "$TRACE" 2>/dev/null || echo "0")
  TRACE_SIZE=$(_stat_size "$TRACE")
  echo "Trace: $TRACE_BLOCKS action blocks, $TRACE_SIZE bytes"
else
  echo "Trace: not initialized"
fi

# Findings count by status
FINDINGS_DIR="$PROJECT_DIR/memory/findings"
F_ACTIVE=$(_fm_count_entries "$FINDINGS_DIR" "active")
F_STALE=$(_fm_count_entries "$FINDINGS_DIR" "stale")
F_TOTAL=$(_fm_count_entries "$FINDINGS_DIR")
echo "Findings: $F_TOTAL total ($F_ACTIVE active, $F_STALE stale)"

# Wisdom count
WISDOM_DIR="$PROJECT_DIR/memory/wisdom"
W_TOTAL=$(_fm_count_entries "$WISDOM_DIR")
echo "Wisdom:   $W_TOTAL entries"

# Sessions archived
SESSION_COUNT=$(find "$PROJECT_DIR/memory/sessions" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
echo "Sessions: $SESSION_COUNT archived"
