#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/util/platform.sh"
source "$SCRIPT_DIR/util/frontmatter.sh"
source "$SCRIPT_DIR/util/sanitize.sh"

PROJECT_DIR="$1"
shift

# Parse optional --id flag
SINGLE_ID=""
if [[ "${1:-}" == "--id" ]]; then
  SINGLE_ID="${2:-}"
  shift 2
fi

EXPORT_DIR="$PROJECT_DIR/memory/_export"
mkdir -p "$EXPORT_DIR"

# Validation level hierarchy for threshold comparison
_val_level_num() {
  case "$1" in
    syntax)      echo "1" ;;
    numerical)   echo "2" ;;
    physical)    echo "3" ;;
    methodology) echo "4" ;;
    *)           echo "0" ;;
  esac
}

# Type-specific minimum validation thresholds
_min_val_for_type() {
  case "$1" in
    EF) echo "2" ;;  # numerical
    CP) echo "3" ;;  # physical
    PI) echo "3" ;;  # physical
    WF) echo "4" ;;  # methodology
    EV) echo "1" ;;  # syntax
    *)  echo "2" ;;  # default numerical
  esac
}

_min_val_name() {
  case "$1" in
    EF) echo "numerical" ;;
    CP) echo "physical" ;;
    PI) echo "physical" ;;
    WF) echo "methodology" ;;
    EV) echo "syntax" ;;
    *)  echo "numerical" ;;
  esac
}

EXPORTED=0
SKIPPED=0

echo "=== HCC Export ==="
echo ""

_process_file() {
  local f="$1"
  local id status scope type val_level

  id=$(_fm_get "$f" "id")
  status=$(_fm_get "$f" "status")
  scope=$(_fm_get "$f" "scope")
  type=$(_fm_get "$f" "type")
  val_level=$(_fm_get "$f" "validation_level")

  # Must be domain-scoped and active
  if [[ "$scope" != "domain" ]]; then
    echo "  SKIP $id: scope=$scope (need domain)"
    ((SKIPPED++)) || true
    return
  fi

  if [[ "$status" != "active" ]]; then
    echo "  SKIP $id: status=$status (need active)"
    ((SKIPPED++)) || true
    return
  fi

  # Check validation threshold for type
  local actual_level required_level
  actual_level=$(_val_level_num "$val_level")
  required_level=$(_min_val_for_type "$type")
  required_name=$(_min_val_name "$type")

  if [[ "$actual_level" -lt "$required_level" ]]; then
    echo "  SKIP $id: validation_level=$val_level (need >= $required_name for type $type)"
    ((SKIPPED++)) || true
    return
  fi

  # Check ## Evidence section exists and non-empty
  local evidence
  evidence=$(awk '/^## Evidence/{found=1;next} /^## [A-Z]/{if(found) exit} found{print}' "$f" | grep -c '[^[:space:]]' 2>/dev/null || echo "0")
  if [[ "$evidence" -eq 0 ]]; then
    echo "  SKIP $id: ## Evidence section empty or missing"
    ((SKIPPED++)) || true
    return
  fi

  # Check ## Failure Boundary section exists and non-empty
  local fb
  fb=$(awk '/^## Failure Boundary/{found=1;next} /^## [A-Z]/{if(found) exit} found{print}' "$f" | grep -c '[^[:space:]]' 2>/dev/null || echo "0")
  if [[ "$fb" -eq 0 ]]; then
    echo "  SKIP $id: ## Failure Boundary section empty or missing"
    ((SKIPPED++)) || true
    return
  fi

  # Sanitize and export
  local tmp_file="$EXPORT_DIR/.tmp_${id}.md"
  local out_file="$EXPORT_DIR/${id}.md"

  if _sanitize_file "$f" "$tmp_file" 2>/dev/null; then
    mv "$tmp_file" "$out_file"
    echo "  EXPORTED $id (type=$type, val=$val_level)"
  else
    mv "$tmp_file" "$out_file"
    echo "  EXPORTED $id (type=$type, val=$val_level) ⚠ manual review needed"
  fi
  ((EXPORTED++)) || true
}

if [[ -n "$SINGLE_ID" ]]; then
  # Single entry export
  FOUND=0
  for dir in "$PROJECT_DIR/memory/findings" "$PROJECT_DIR/memory/wisdom"; do
    candidate="$dir/${SINGLE_ID}.md"
    if [[ -f "$candidate" ]]; then
      _process_file "$candidate"
      FOUND=1
      break
    fi
  done
  [[ $FOUND -eq 0 ]] && echo "ERROR: Entry $SINGLE_ID not found." >&2 && exit 1
else
  # Scan all findings and wisdom
  for dir in "$PROJECT_DIR/memory/findings" "$PROJECT_DIR/memory/wisdom"; do
    for f in "$dir"/*.md; do
      [[ "$(basename "$f")" == "_index.md" ]] && continue
      [[ ! -f "$f" ]] && continue
      _process_file "$f"
    done
  done
fi

echo ""
echo "Exported: $EXPORTED  Skipped: $SKIPPED"
echo "Output:   $EXPORT_DIR/"
