#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/util/platform.sh"
source "$SCRIPT_DIR/util/frontmatter.sh"

PROJECT_DIR="$1"
ID="$2"

# Find the file by ID
FILE=""
for dir in "$PROJECT_DIR/memory/findings" "$PROJECT_DIR/memory/wisdom"; do
  candidate=$(find "$dir" -name "${ID}.md" 2>/dev/null | head -1)
  if [[ -n "$candidate" && -f "$candidate" ]]; then
    FILE="$candidate"
    break
  fi
done

if [[ -z "$FILE" ]]; then
  echo "ERROR: Entry $ID not found." >&2
  exit 1
fi

DATE=$(_date_short)
_fm_set "$FILE" "updated_at" "\"$DATE\""

STATUS=$(_fm_get "$FILE" "status")
if [[ "$STATUS" == "stale" ]]; then
  _fm_set "$FILE" "status" "active"
  echo "Reactivated stale entry: $ID"
else
  echo "Touched: $ID (updated_at = $DATE)"
fi
