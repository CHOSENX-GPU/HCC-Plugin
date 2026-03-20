#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/util/platform.sh"

PROJECT_DIR="$1"
shift

# Parse optional flags before the brief description
PHASE=""
while [[ "${1:-}" == --* ]]; do
  case "$1" in
    --phase) PHASE="$2"; shift 2 ;;
    *) shift ;;
  esac
done
BRIEF="$*"

TRACE="$PROJECT_DIR/memory/trace.md"
CONFIG="$PROJECT_DIR/.hcc/config.yaml"
STATE="$PROJECT_DIR/.hcc/state.json"

if [[ ! -f "$TRACE" ]]; then
  echo "ERROR: trace.md not found. Run init-memory.sh first." >&2
  exit 1
fi

# Read action count; only increment if not called from hook (which already incremented)
ACTION_COUNT=$(_json_get "$STATE" "action_count")
ACTION_COUNT=${ACTION_COUNT:-0}
if [[ "${HCC_NO_INCREMENT:-}" != "1" ]]; then
  ACTION_COUNT=$((ACTION_COUNT + 1))
  _json_set "$STATE" "action_count" "$ACTION_COUNT"
fi

# Get current time for the block header
TIME_HM=$(date -u +"%H:%M")

# Read optional stdin content
DETAIL=""
if [[ ! -t 0 ]]; then
  DETAIL=$(cat)
fi

# Build header line based on phase
case "$PHASE" in
  plan)        HEADER="## [$TIME_HM] 🧠 PLAN -- ${BRIEF}" ;;
  exec)        HEADER="## [$TIME_HM] 🔧 EXEC -- ${BRIEF}" ;;
  check)       HEADER="## [$TIME_HM] ✅ CHECK -- ${BRIEF}" ;;
  done)        HEADER="## [$TIME_HM] 📋 DONE -- ${BRIEF}" ;;
  error)       HEADER="## [$TIME_HM] ❌ ERROR -- ${BRIEF}" ;;
  checkpoint)  HEADER="## [$TIME_HM] ⏱ CHECKPOINT -- ${BRIEF}" ;;
  turn)        HEADER="## [$TIME_HM] ⏸ TURN -- ${BRIEF}" ;;
  session_end) HEADER="## [$TIME_HM] 🔚 SESSION END -- ${BRIEF}" ;;
  "")          HEADER="## [$TIME_HM] Action-${ACTION_COUNT} -- ${BRIEF}" ;;
  *)           HEADER="## [$TIME_HM] ${PHASE} -- ${BRIEF}" ;;
esac

# Append block to trace.md
{
  echo ""
  echo "$HEADER"
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
    mkdir -p "$PROJECT_DIR/memory/sessions"
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

  mkdir -p "$PROJECT_DIR/memory/sessions"
  ARCHIVE_TS=$(date -u +"%Y-%m-%d-%H%M%S")
  echo "$FIRST_BLOCK" > "$PROJECT_DIR/memory/sessions/S-${ARCHIVE_TS}.md"

  {
    echo "$HEADER"
    awk 'BEGIN { block=0 } /^## \[/ { block++ } block >= 2 { print }' "$TRACE"
  } > "${TRACE}.tmp"
  mv "${TRACE}.tmp" "$TRACE"

  CURRENT_SIZE=$(_stat_size "$TRACE")
done
