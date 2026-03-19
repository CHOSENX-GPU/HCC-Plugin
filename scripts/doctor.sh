#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/util/platform.sh"
source "$SCRIPT_DIR/util/frontmatter.sh"

PROJECT_DIR="$1"
ISSUES=0
CHECKED=0
STALED=0
INDEX_REBUILT=0

_warn() {
  echo "  ⚠  $1"
  ((ISSUES++)) || true
}

_ok() {
  echo "  ✓  $1"
}

echo "=== HCC Doctor ==="
echo ""

# 1. Environment checks
echo "--- Environment ---"

BASH_VER="${BASH_VERSINFO[0]:-0}"
if [[ "$BASH_VER" -ge 4 ]]; then
  _ok "Bash >= 4.0 ($BASH_VERSION)"
else
  _warn "Bash < 4.0 ($BASH_VERSION) — some features may not work"
fi

if command -v jq &>/dev/null; then
  _ok "jq available ($(jq --version 2>&1))"
else
  _warn "jq not found — promote and compact require it"
fi

if command -v sed &>/dev/null && command -v awk &>/dev/null && command -v grep &>/dev/null; then
  _ok "coreutils available (sed, awk, grep)"
else
  _warn "Missing coreutils"
fi
echo ""

# 2. Directory structure
echo "--- Directory Structure ---"
for dir in memory memory/findings memory/wisdom memory/tasks memory/sessions .hcc; do
  if [[ -d "$PROJECT_DIR/$dir" ]]; then
    _ok "$dir/"
  else
    _warn "Missing $dir/"
  fi
done

for f in .hcc/config.yaml .hcc/state.json memory/trace.md memory/findings/_index.md memory/wisdom/_index.md; do
  if [[ -f "$PROJECT_DIR/$f" ]]; then
    _ok "$f"
  else
    _warn "Missing $f"
  fi
done
echo ""

# 3. Config validation
echo "--- Config ---"
CONFIG="$PROJECT_DIR/.hcc/config.yaml"
if [[ -f "$CONFIG" ]]; then
  if grep -q "version:" "$CONFIG" && grep -q "flush_interval:" "$CONFIG"; then
    _ok "config.yaml format valid"
  else
    _warn "config.yaml missing required fields"
  fi
fi
echo ""

# 4. Entry validation
echo "--- Entry Validation ---"
STALE_DAYS=$(grep "stale_threshold_days:" "$CONFIG" 2>/dev/null | awk '{print $2}')
STALE_DAYS=${STALE_DAYS:-180}
TODAY_EPOCH=$(date -u +%s)

for dir in "$PROJECT_DIR/memory/findings" "$PROJECT_DIR/memory/wisdom"; do
  for f in "$dir"/*.md; do
    [[ "$(basename "$f")" == "_index.md" ]] && continue
    [[ ! -f "$f" ]] && continue
    ((CHECKED++)) || true

    local_id=$(_fm_get "$f" "id")
    local_status=$(_fm_get "$f" "status")
    local_schema=$(_fm_get "$f" "schema_version")

    # Validate front matter
    if ! grep -q "^---$" "$f"; then
      _warn "$local_id: Missing front matter delimiters"
      continue
    fi

    # Required fields
    for field in id title scope type status validation_level schema_version; do
      val=$(_fm_get "$f" "$field")
      if [[ -z "$val" ]]; then
        _warn "$local_id: Missing required field '$field'"
      fi
    done

    # Body sections
    if ! grep -q "^## Problem" "$f"; then
      _warn "$local_id: Missing ## Problem section"
    fi
    if ! grep -q "^## Action" "$f"; then
      _warn "$local_id: Missing ## Action section"
    fi

    # Auto-stale check
    if [[ "$local_status" == "active" ]]; then
      local_updated=$(_fm_get "$f" "updated_at")
      if [[ -n "$local_updated" ]]; then
        # Parse date (remove quotes, handle YYYY-MM-DD format)
        local_updated_clean=$(echo "$local_updated" | tr -d '"')
        if [[ "$local_updated_clean" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
          updated_epoch=$(date -u -d "${local_updated_clean}" +%s 2>/dev/null || echo "0")
          if [[ "$updated_epoch" -gt 0 ]]; then
            days_old=$(( (TODAY_EPOCH - updated_epoch) / 86400 ))
            if [[ "$days_old" -gt "$STALE_DAYS" ]]; then
              _fm_set "$f" "status" "stale"
              echo "  →  Auto-staled: $local_id (${days_old} days old)"
              ((STALED++)) || true
            fi
          fi
        fi
      fi
    fi

    # Supersedes validation
    local_supersedes=$(_fm_get "$f" "supersedes")
    if [[ -n "$local_supersedes" && "$local_supersedes" != "[]" ]]; then
      # Extract IDs from array
      echo "$local_supersedes" | tr -d '[]' | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' | while read -r ref_id; do
        ref_id=$(echo "$ref_id" | tr -d '"' | tr -d ' ')
        ref_found=0
        for search_dir in "$PROJECT_DIR/memory/findings" "$PROJECT_DIR/memory/wisdom"; do
          if [[ -f "$search_dir/${ref_id}.md" ]]; then
            ref_found=1
            break
          fi
        done
        if [[ "$ref_found" -eq 0 ]]; then
          _warn "$local_id: supersedes reference '$ref_id' not found"
        fi
      done
    fi
  done
done
echo ""

# 5. Index consistency
echo "--- Index Consistency ---"
for dir in "$PROJECT_DIR/memory/findings" "$PROJECT_DIR/memory/wisdom"; do
  INDEX="$dir/_index.md"
  dir_name=$(basename "$dir")
  if [[ ! -f "$INDEX" ]]; then
    _warn "$dir_name/_index.md missing"
    continue
  fi

  actual_count=0
  for f in "$dir"/*.md; do
    [[ "$(basename "$f")" == "_index.md" ]] && continue
    [[ ! -f "$f" ]] && continue
    ((actual_count++)) || true
  done

  # Count entries in index (lines with | F- or | W- pattern)
  index_count=$(grep -c "^| [FW]-" "$INDEX" 2>/dev/null || true)
  index_count=${index_count:-0}
  index_count=$(echo "$index_count" | tr -d '[:space:]')

  if [[ "$actual_count" -ne "$index_count" ]]; then
    _warn "$dir_name: index has $index_count entries but $actual_count files exist. Rebuilding..."
    bash "$SCRIPT_DIR/util/index-rebuild.sh" "$dir"
    INDEX_REBUILT=1
  else
    _ok "$dir_name: index consistent ($actual_count entries)"
  fi
done
echo ""

# Summary
echo "=== Summary ==="
echo "Files checked: $CHECKED"
echo "Issues found:  $ISSUES"
echo "Entries staled: $STALED"
echo "Index rebuilt:  $([ $INDEX_REBUILT -eq 1 ] && echo 'Yes' || echo 'No')"

if [[ $ISSUES -eq 0 ]]; then
  echo "✓ All checks passed."
else
  echo "⚠ $ISSUES issue(s) found. Review above."
fi
