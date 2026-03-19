#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/platform.sh"
source "$SCRIPT_DIR/frontmatter.sh"

DIR="$1"
INDEX="$DIR/_index.md"
DATE=$(_date_iso)
DIR_NAME=$(basename "$DIR")

# Status sort order
_status_order() {
  case "$1" in
    active)     echo "1" ;;
    stale)      echo "2" ;;
    deprecated) echo "3" ;;
    archived)   echo "4" ;;
    *)          echo "5" ;;
  esac
}

# Validation level marker
_val_marker() {
  case "$1" in
    syntax)      echo "[syntax]" ;;
    numerical)   echo "[numerical⚠️]" ;;
    physical)    echo "[physical✓]" ;;
    methodology) echo "[methodology✓✓]" ;;
    *)           echo "[$1]" ;;
  esac
}

if [[ "$DIR_NAME" == "findings" ]]; then
  cat > "$INDEX" << EOF
# Findings Index

> Auto-generated. Do not edit manually.
> Last rebuilt: $DATE

| ID | Type | Title | Status | Confidence | Validation |
|----|------|-------|--------|------------|------------|
EOF

  # Collect entries with sort keys
  declare -a entries=()
  for f in "$DIR"/*.md; do
    [[ "$(basename "$f")" == "_index.md" ]] && continue
    [[ ! -f "$f" ]] && continue
    local_id=$(_fm_get "$f" "id")
    local_type=$(_fm_get "$f" "type")
    local_title=$(_fm_get "$f" "title")
    local_status=$(_fm_get "$f" "status")
    local_conf=$(_fm_get "$f" "confidence")
    local_val=$(_fm_get "$f" "validation_level")
    local_val_marker=$(_val_marker "$local_val")
    local_sort=$(_status_order "$local_status")
    entries+=("${local_sort}|${local_type}|${local_id}|${local_title}|${local_status}|${local_conf}|${local_val_marker}")
  done

  # Sort and output
  if [[ ${#entries[@]} -gt 0 ]]; then
    printf '%s\n' "${entries[@]}" | sort -t'|' -k1,1n -k2,2 | while IFS='|' read -r _ etype eid etitle estatus econf eval_m; do
      echo "| $eid | $etype | $etitle | $estatus | $econf | $eval_m |" >> "$INDEX"
    done
  fi

elif [[ "$DIR_NAME" == "wisdom" ]]; then
  cat > "$INDEX" << EOF
# Wisdom Index

> Auto-generated. Do not edit manually.
> Last rebuilt: $DATE

| ID | Type | Title | Validation |
|----|------|-------|------------|
EOF

  for f in "$DIR"/*.md; do
    [[ "$(basename "$f")" == "_index.md" ]] && continue
    [[ ! -f "$f" ]] && continue
    local_id=$(_fm_get "$f" "id")
    local_type=$(_fm_get "$f" "type")
    local_title=$(_fm_get "$f" "title")
    local_val=$(_fm_get "$f" "validation_level")
    local_val_marker=$(_val_marker "$local_val")
    echo "| $local_id | $local_type | $local_title | $local_val_marker |" >> "$INDEX"
  done
fi

echo "Index rebuilt: $INDEX"
