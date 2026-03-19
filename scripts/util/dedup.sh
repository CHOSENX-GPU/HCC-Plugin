#!/usr/bin/env bash
# Duplicate detection for HCC Memory entries

DEDUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DEDUP_DIR/platform.sh"
source "$DEDUP_DIR/frontmatter.sh"

_find_similar_entries() {
  local search_dir="$1"
  local search_type="$2"
  local search_tags_csv="$3"

  # Parse search tags into array (lowercase)
  local -a search_tags=()
  IFS=',' read -ra raw_tags <<< "$search_tags_csv"
  for t in "${raw_tags[@]}"; do
    t=$(echo "$t" | tr -d ' ' | tr '[:upper:]' '[:lower:]')
    [[ -n "$t" ]] && search_tags+=("$t")
  done

  local found=0
  for f in "$search_dir"/*.md; do
    [[ "$(basename "$f")" == "_index.md" ]] && continue
    [[ ! -f "$f" ]] && continue

    local existing_type
    existing_type=$(_fm_get "$f" "type")

    # Type must match exactly
    [[ "$existing_type" != "$search_type" ]] && continue

    # Count tag overlap
    local existing_tags_raw
    existing_tags_raw=$(_fm_get "$f" "tags")
    local common=0

    for st in "${search_tags[@]}"; do
      if echo "$existing_tags_raw" | tr '[:upper:]' '[:lower:]' | grep -q "$st" 2>/dev/null; then
        ((common++)) || true
      fi
    done

    if [[ $common -ge 2 ]]; then
      local eid etitle etags
      eid=$(_fm_get "$f" "id")
      etitle=$(_fm_get "$f" "title")
      etags=$(_fm_get "$f" "tags")
      echo "${eid}|${etitle}|${etags}"
      found=1
    fi
  done

  return $( [[ $found -eq 1 ]] && echo 0 || echo 1 )
}
