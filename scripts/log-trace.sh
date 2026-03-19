#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/util/platform.sh"

PROJECT_DIR="$1"
shift
BRIEF="$*"

TRACE="$PROJECT_DIR/memory/trace.md"
CONFIG="$PROJECT_DIR/.hcc/config.yaml"
STATE="$PROJECT_DIR/.hcc/state.json"

if [[ ! -f "$TRACE" ]]; then
  echo "ERROR: trace.md not found. Run init-memory.sh first." >&2
  exit 1
fi

# Read and increment action count
ACTION_COUNT=$(_json_get "$STATE" "action_count")
ACTION_COUNT=${ACTION_COUNT:-0}
ACTION_COUNT=$((ACTION_COUNT + 1))
_json_set "$STATE" "action_count" "$ACTION_COUNT"

# Get current time for the block header
TIME_HM=$(date -u +"%H:%M")

# Read optional stdin content
DETAIL=""
if [[ ! -t 0 ]]; then
  DETAIL=$(cat)
fi

# Append Action block to trace.md
{
  echo ""
  echo "## [$TIME_HM] Action-${ACTION_COUNT} -- ${BRIEF}"
  if [[ -n "$DETAIL" ]]; then
    echo ""
    echo "$DETAIL"
  fi
} >> "$TRACE"

# Read limits from config
MAX_ENTRIES=$(grep "trace_max_entries:" "$CONFIG" 2>/dev/null | awk '{print $2}')
MAX_BYTES=$(grep "trace_max_bytes:" "$CONFIG" 2>/dev/null | awk '{print $2}')
MAX_ENTRIES=${MAX_ENTRIES:-30}
MAX_BYTES=${MAX_BYTES:-12288}

# Count current Action blocks (lines starting with "## [")
ENTRY_COUNT=$(grep -c "^## \[" "$TRACE" 2>/dev/null || true)

# Rolling window: archive oldest blocks if over limit
if [[ "$ENTRY_COUNT" -gt "$MAX_ENTRIES" ]]; then
  while [[ $(grep -c "^## \[" "$TRACE" 2>/dev/null || echo 0) -gt "$MAX_ENTRIES" ]]; do
    # Extract header (everything before first ## [)
    HEADER=$(awk '/^## \[/{exit} {print}' "$TRACE")

    # Extract first Action block (from first ## [ to second ## [ or EOF)
    FIRST_BLOCK=$(awk '
      /^## \[/ { if (found) exit; found=1 }
      found { print }
    ' "$TRACE")

    # Archive the first block
    ARCHIVE_TS=$(date -u +"%Y-%m-%d-%H%M")
    ARCHIVE_FILE="$PROJECT_DIR/memory/sessions/S-${ARCHIVE_TS}.md"
    echo "$FIRST_BLOCK" > "$ARCHIVE_FILE"

    # Remove the first block from trace: keep header + everything after first block
    {
      echo "$HEADER"
      awk '
        BEGIN { block=0 }
        /^## \[/ { block++ }
        block >= 2 { print }
      ' "$TRACE"
    } > "${TRACE}.tmp"
    mv "${TRACE}.tmp" "$TRACE"
  done
fi

# Also check byte size
CURRENT_SIZE=$(_stat_size "$TRACE")
while [[ "$CURRENT_SIZE" -gt "$MAX_BYTES" ]]; do
  BLOCK_COUNT=$(grep -c "^## \[" "$TRACE" 2>/dev/null || echo 0)
  [[ "$BLOCK_COUNT" -le 1 ]] && break

  HEADER=$(awk '/^## \[/{exit} {print}' "$TRACE")
  FIRST_BLOCK=$(awk '/^## \[/ { if (found) exit; found=1 } found { print }' "$TRACE")

  ARCHIVE_TS=$(date -u +"%Y-%m-%d-%H%M%S")
  echo "$FIRST_BLOCK" > "$PROJECT_DIR/memory/sessions/S-${ARCHIVE_TS}.md"

  {
    echo "$HEADER"
    awk 'BEGIN { block=0 } /^## \[/ { block++ } block >= 2 { print }' "$TRACE"
  } > "${TRACE}.tmp"
  mv "${TRACE}.tmp" "$TRACE"

  CURRENT_SIZE=$(_stat_size "$TRACE")
done
