#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/util/platform.sh"

# Read stdin JSON (SessionStart receives source: startup|resume|clear|compact)
INPUT=""
if [[ ! -t 0 ]]; then
  INPUT=$(cat)
fi

# Resolve project root (fixes pwd bug -- same as action-counter.sh)
PROJECT_DIR="$(_project_root "$(pwd)")" || exit 0

[[ ! -d "$PROJECT_DIR/memory" ]] && exit 0

# On compact: re-inject recent trace summary to Claude's context
# (SessionStart stdout IS injected into context per official docs)
if [[ -n "$INPUT" ]] && command -v jq &>/dev/null; then
  SOURCE=$(echo "$INPUT" | jq -r '.source // "startup"')
  if [[ "$SOURCE" == "compact" ]]; then
    TRACE="$PROJECT_DIR/memory/trace.md"
    if [[ -f "$TRACE" ]]; then
      RECENT=$(tail -50 "$TRACE" | grep -A3 "^## \[" | tail -20)
      if [[ -n "$RECENT" ]]; then
        echo "📋 [HCC] Recent trace (re-injected after compaction):"
        echo "$RECENT"
      fi
    fi
  fi
fi

# On startup/resume: check for active task
ACTIVE="$PROJECT_DIR/memory/tasks/_active.md"
[[ ! -f "$ACTIVE" ]] && exit 0
[[ ! -s "$ACTIVE" ]] && exit 0

source "$SCRIPT_DIR/util/frontmatter.sh"

STATUS=$(_fm_get "$ACTIVE" "status")
if [[ "$STATUS" == "active" ]]; then
  TASK=$(_fm_get "$ACTIVE" "task")
  echo "📋 [HCC] Active task detected: '$TASK'. Run /hcc-memory:recover to restore context."
fi
