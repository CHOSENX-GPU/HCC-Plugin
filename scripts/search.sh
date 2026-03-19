#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/util/platform.sh"
source "$SCRIPT_DIR/util/frontmatter.sh"

PROJECT_DIR="$1"
shift
KEYWORDS="$*"
MAX_RESULTS=5

if [[ -z "$KEYWORDS" ]]; then
  echo "Usage: search.sh <project_dir> <keywords>" >&2
  exit 1
fi

WISDOM_DIR="$PROJECT_DIR/memory/wisdom"
FINDINGS_DIR="$PROJECT_DIR/memory/findings"

# Validation level sort order (higher = better)
_val_order() {
  case "$1" in
    methodology) echo "4" ;;
    physical)    echo "3" ;;
    numerical)   echo "2" ;;
    syntax)      echo "1" ;;
    *)           echo "0" ;;
  esac
}

_val_marker() {
  case "$1" in
    syntax)      echo "[syntax]" ;;
    numerical)   echo "[numerical⚠️]" ;;
    physical)    echo "[physical✓]" ;;
    methodology) echo "[methodology✓✓]" ;;
    *)           echo "[$1]" ;;
  esac
}

declare -a RESULTS=()

_search_dir() {
  local dir="$1" priority="$2"
  for f in "$dir"/*.md; do
    [[ "$(basename "$f")" == "_index.md" ]] && continue
    [[ ! -f "$f" ]] && continue

    # Extract searchable sections
    local title tags problem_section action_section
    title=$(_fm_get "$f" "title")
    tags=$(_fm_get "$f" "tags")

    # Extract ## Problem and ## Action body sections
    problem_section=$(awk '/^## Problem/{found=1;next} /^## [A-Z]/{if(found) exit} found{print}' "$f")
    action_section=$(awk '/^## Action/{found=1;next} /^## [A-Z]/{if(found) exit} found{print}' "$f")

    local searchable="${title} ${tags} ${problem_section} ${action_section}"

    # Check if any keyword matches (case insensitive)
    local match=0
    for kw in $KEYWORDS; do
      if echo "$searchable" | grep -qi "$kw" 2>/dev/null; then
        ((match++)) || true
      fi
    done

    if [[ $match -gt 0 ]]; then
      local id status val_level confidence
      id=$(_fm_get "$f" "id")
      status=$(_fm_get "$f" "status")
      val_level=$(_fm_get "$f" "validation_level")
      confidence=$(_fm_get "$f" "confidence")

      # Skip archived/deprecated
      [[ "$status" == "archived" || "$status" == "deprecated" ]] && continue

      local stale_priority="$priority"
      [[ "$status" == "stale" ]] && stale_priority=$((priority + 10))

      local val_ord
      val_ord=$(_val_order "$val_level")
      # Invert for sort (we want higher val first)
      local val_sort=$((10 - val_ord))

      RESULTS+=("${stale_priority}|${val_sort}|${match}|${id}|${title}|${status}|${val_level}|${confidence}|${tags}|${f}")
    fi
  done
}

# Search wisdom first (priority 1), then findings (priority 2)
_search_dir "$WISDOM_DIR" "1"
_search_dir "$FINDINGS_DIR" "2"

if [[ ${#RESULTS[@]} -eq 0 ]]; then
  echo "No results found for: $KEYWORDS"
  exit 0
fi

# Sort by priority, then val_sort, then match count desc
IFS=$'\n' SORTED=($(printf '%s\n' "${RESULTS[@]}" | sort -t'|' -k1,1n -k2,2n -k3,3rn))

echo "=== Search Results for: $KEYWORDS ==="
echo ""

COUNT=0
for result in "${SORTED[@]}"; do
  [[ $COUNT -ge $MAX_RESULTS ]] && break
  IFS='|' read -r _ _ _ id title status val_level confidence tags filepath <<< "$result"

  local_val_marker=$(_val_marker "$val_level")
  local_status_marker=""
  [[ "$status" == "stale" ]] && local_status_marker=" [stale]"

  echo "  $id ${status}${local_status_marker} ${local_val_marker}"
  echo "    Title: $title"
  echo "    Tags: $tags | Confidence: $confidence"
  echo "    File: $filepath"
  if [[ "$val_level" == "numerical" ]]; then
    echo "    ⚠️  convergence verified, physics unverified"
  fi
  echo ""
  ((COUNT++)) || true
done

echo "($COUNT of ${#RESULTS[@]} results shown)"
