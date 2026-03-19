#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/util/platform.sh"
source "$SCRIPT_DIR/util/frontmatter.sh"

PROJECT_DIR="$1"
shift
TASK_DESC="$*"
FORCE=0

# Check for --force flag (last argument)
if [[ "${!#}" == "--force" ]]; then
  FORCE=1
  # Remove --force from TASK_DESC
  TASK_DESC="${TASK_DESC% --force}"
fi

if [[ -z "$TASK_DESC" ]]; then
  echo "ERROR: Task description required." >&2
  echo "Usage: plan.sh <project_dir> <task description> [--force]" >&2
  exit 1
fi

if [[ ! -d "$PROJECT_DIR/memory" ]]; then
  echo "ERROR: memory/ not found. Run init-memory.sh first." >&2
  exit 1
fi

ACTIVE="$PROJECT_DIR/memory/tasks/_active.md"

# Check for existing active task
if [[ -f "$ACTIVE" ]]; then
  CURRENT_STATUS=$(_fm_get "$ACTIVE" "status")
  if [[ "$CURRENT_STATUS" == "active" ]]; then
    CURRENT_TASK=$(_fm_get "$ACTIVE" "task")
    if [[ "$FORCE" -eq 0 ]]; then
      echo "ERROR: Active task already exists: $CURRENT_TASK" >&2
      echo "Complete it first with /hcc-memory:complete or use --force." >&2
      exit 1
    else
      # Archive current task
      local_date=$(_date_short)
      local_desc=$(echo "$CURRENT_TASK" | tr ' ' '-' | tr -cd '[:alnum:]-' | cut -c1-30)
      mv "$ACTIVE" "$PROJECT_DIR/memory/tasks/T-${local_date}-${local_desc}.md"
    fi
  fi
fi

DATE=$(_date_iso)

# Create new _active.md from template
TMPL="$SCRIPT_DIR/../templates/task-active.md.tmpl"
if [[ -f "$TMPL" ]]; then
  sed -e "s|{{TASK}}|$TASK_DESC|g" \
      -e "s|{{DATE}}|$DATE|g" \
      "$TMPL" > "$ACTIVE"
else
  cat > "$ACTIVE" << EOF
---
task: "$TASK_DESC"
started_at: "$DATE"
status: active
action_count: 0
---

## Plan

$TASK_DESC

## Progress

(auto-updated by 5-Action Rule)
EOF
fi

# Reinitialize trace.md with task header
TRACE_TMPL="$SCRIPT_DIR/../templates/trace-header.md.tmpl"
if [[ -f "$TRACE_TMPL" ]]; then
  sed -e "s|{{TASK}}|$TASK_DESC|g" \
      -e "s|{{DATE}}|$DATE|g" \
      "$TRACE_TMPL" > "$PROJECT_DIR/memory/trace.md"
else
  cat > "$PROJECT_DIR/memory/trace.md" << EOF
# Execution Trace

> Task: $TASK_DESC
> Session started: $DATE
EOF
fi

# Update state.json
_json_set "$PROJECT_DIR/.hcc/state.json" "action_count" "0"
_json_set "$PROJECT_DIR/.hcc/state.json" "active_task" "\"$TASK_DESC\""

echo "Task started: $TASK_DESC"
echo "Action counter reset. 5-Action Rule active."
