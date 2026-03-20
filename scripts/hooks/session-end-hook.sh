#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/util/platform.sh"

PROJECT_DIR="$(_project_root "$(pwd)")" || exit 0
[[ ! -d "$PROJECT_DIR/memory" ]] && exit 0
[[ ! -f "$PROJECT_DIR/memory/trace.md" ]] && exit 0

TICKS="$PROJECT_DIR/.hcc/action_ticks"

# Read count from the atomic ticks file (source of truth)
if [[ -f "$TICKS" ]]; then
  COUNT=$(wc -l < "$TICKS" | tr -d ' ')
else
  COUNT=0
fi
[[ "$COUNT" -eq 0 ]] && exit 0

# Flush any remaining tool activity since the last checkpoint
LAST_CP_FILE="$PROJECT_DIR/.hcc/last_checkpoint.tmp"
LAST_CP=$(cat "$LAST_CP_FILE" 2>/dev/null || echo "0")
LAST_CP=$(echo "$LAST_CP" | tr -d '[:space:]')
LAST_CP=${LAST_CP:-0}

if [[ "$COUNT" -gt "$LAST_CP" && -f "$TICKS" ]]; then
  RANGE_START=$((LAST_CP + 1))
  ACTIVITY=$(tail -n "+${RANGE_START}" "$TICKS" | head -n "$((COUNT - LAST_CP))")
  if [[ -n "$ACTIVITY" ]]; then
    echo "$ACTIVITY" | HCC_NO_INCREMENT=1 bash "$SCRIPT_DIR/log-trace.sh" \
      "$PROJECT_DIR" --phase checkpoint "Actions ${RANGE_START}-${COUNT}"
  fi
fi

# Write session-end summary
HCC_NO_INCREMENT=1 bash "$SCRIPT_DIR/log-trace.sh" "$PROJECT_DIR" \
  --phase session_end "Total actions: ${COUNT}"

# Safety net: auto-archive trace so data is never lost even if
# /hcc-memory:complete was never run during the session.
ARCHIVE_TS=$(date -u +"%Y-%m-%d-%H%M")
mkdir -p "$PROJECT_DIR/memory/sessions"
cp "$PROJECT_DIR/memory/trace.md" "$PROJECT_DIR/memory/sessions/S-${ARCHIVE_TS}-auto.md"
