#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/util/platform.sh"
source "$SCRIPT_DIR/util/frontmatter.sh"

PROJECT_DIR="$1"
SPECIFIC="${2:-}"

PASSED=0
WITH_ISSUES=0

VALID_SCOPES="session project domain"
VALID_TYPES="EF CP PI WF EV CN"
VALID_STATUSES="active stale archived deprecated"
VALID_VALIDATIONS="syntax numerical physical methodology"

_validate_file() {
  local f="$1"
  local fname
  fname=$(basename "$f")
  local issues=0

  # Check front matter exists
  local fm_count
  fm_count=$(grep -c "^---$" "$f" 2>/dev/null || echo "0")
  if [[ "$fm_count" -lt 2 ]]; then
    echo "  $f: Missing front matter (need two --- delimiters)"
    ((WITH_ISSUES++)) || true
    return
  fi

  # Schema version
  local schema
  schema=$(_fm_get "$f" "schema_version")
  if [[ -z "$schema" ]]; then
    echo "  $f: Missing schema_version"
    ((issues++)) || true
  elif [[ "$schema" != "1" ]]; then
    echo "  $f: schema_version='$schema' (expected '1')"
    ((issues++)) || true
  fi

  # Required fields
  for field in id title scope type status validation_level; do
    local val
    val=$(_fm_get "$f" "$field")
    if [[ -z "$val" ]]; then
      echo "  $f: Missing required field '$field'"
      ((issues++)) || true
    fi
  done

  # Validate scope
  local scope
  scope=$(_fm_get "$f" "scope")
  if [[ -n "$scope" ]] && ! echo "$VALID_SCOPES" | grep -wq "$scope"; then
    echo "  $f: Invalid scope='$scope' (expected: $VALID_SCOPES)"
    ((issues++)) || true
  fi

  # Validate type
  local type
  type=$(_fm_get "$f" "type")
  if [[ -n "$type" ]] && ! echo "$VALID_TYPES" | grep -wq "$type"; then
    echo "  $f: Invalid type='$type' (expected: $VALID_TYPES)"
    ((issues++)) || true
  fi

  # Validate status
  local status
  status=$(_fm_get "$f" "status")
  if [[ -n "$status" ]] && ! echo "$VALID_STATUSES" | grep -wq "$status"; then
    echo "  $f: Invalid status='$status' (expected: $VALID_STATUSES)"
    ((issues++)) || true
  fi

  # Validate validation_level
  local val_level
  val_level=$(_fm_get "$f" "validation_level")
  if [[ -n "$val_level" ]] && ! echo "$VALID_VALIDATIONS" | grep -wq "$val_level"; then
    echo "  $f: Invalid validation_level='$val_level' (expected: $VALID_VALIDATIONS)"
    ((issues++)) || true
  fi

  # Body sections
  if ! grep -q "^## Problem" "$f" 2>/dev/null; then
    echo "  $f: Missing ## Problem section"
    ((issues++)) || true
  fi
  if ! grep -q "^## Action" "$f" 2>/dev/null; then
    echo "  $f: Missing ## Action section"
    ((issues++)) || true
  fi

  if [[ $issues -eq 0 ]]; then
    ((PASSED++)) || true
  else
    ((WITH_ISSUES++)) || true
  fi
}

echo "=== HCC Validate ==="
echo ""

if [[ -n "$SPECIFIC" ]]; then
  # Validate single file or ID
  if [[ -f "$SPECIFIC" ]]; then
    _validate_file "$SPECIFIC"
  else
    # Try to find by ID
    FOUND=0
    for dir in "$PROJECT_DIR/memory/findings" "$PROJECT_DIR/memory/wisdom"; do
      if [[ -f "$dir/${SPECIFIC}.md" ]]; then
        _validate_file "$dir/${SPECIFIC}.md"
        FOUND=1
        break
      fi
    done
    [[ $FOUND -eq 0 ]] && echo "Entry not found: $SPECIFIC" && exit 1
  fi
else
  # Validate all entries
  for dir in "$PROJECT_DIR/memory/findings" "$PROJECT_DIR/memory/wisdom"; do
    [[ ! -d "$dir" ]] && continue
    for f in "$dir"/*.md; do
      [[ "$(basename "$f")" == "_index.md" ]] && continue
      [[ ! -f "$f" ]] && continue
      _validate_file "$f"
    done
  done
fi

echo ""
echo "=== Summary ==="
echo "Passed:     $PASSED"
echo "With issues: $WITH_ISSUES"
