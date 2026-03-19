#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Silently exit if no memory system
[[ ! -d "$PROJECT_DIR/memory" ]] && exit 0

ACTIVE="$PROJECT_DIR/memory/tasks/_active.md"
[[ ! -f "$ACTIVE" ]] && exit 0

# Check if file has content (not just empty)
[[ ! -s "$ACTIVE" ]] && exit 0

source "$SCRIPT_DIR/util/frontmatter.sh"

STATUS=$(_fm_get "$ACTIVE" "status")
if [[ "$STATUS" == "active" ]]; then
  TASK=$(_fm_get "$ACTIVE" "task")
  echo "📋 [HCC] Active task detected: '$TASK'. Run /hcc-memory:recover to restore context."
fi
