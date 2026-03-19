#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/util/platform.sh"
source "$SCRIPT_DIR/util/frontmatter.sh"
source "$SCRIPT_DIR/util/dedup.sh"

PROJECT_DIR="$1"
FINDINGS_DIR="$PROJECT_DIR/memory/findings"
WISDOM_DIR="$PROJECT_DIR/memory/wisdom"

if [[ "${2:-}" == "--apply" ]]; then
  # Apply mode
  if ! _has_jq; then
    echo "ERROR: jq required for --apply mode" >&2
    exit 1
  fi

  PAYLOAD="$3"
  ACTION_TYPE=$(echo "$PAYLOAD" | jq -r '.action')
  TARGET_ID=$(echo "$PAYLOAD" | jq -r '.target_id')

  case "$ACTION_TYPE" in
    archive)
      TARGET_FILE=""
      for dir in "$FINDINGS_DIR" "$WISDOM_DIR"; do
        [[ -f "$dir/${TARGET_ID}.md" ]] && TARGET_FILE="$dir/${TARGET_ID}.md" && break
      done

      if [[ -z "$TARGET_FILE" ]]; then
        echo "ERROR: Entry $TARGET_ID not found." >&2
        exit 1
      fi

      _fm_set "$TARGET_FILE" "status" "archived"
      echo "Archived: $TARGET_ID"
      ;;

    merge_into)
      SOURCE_ID=$(echo "$PAYLOAD" | jq -r '.source_id')

      # Find both files
      TARGET_FILE="" SOURCE_FILE=""
      for dir in "$FINDINGS_DIR" "$WISDOM_DIR"; do
        [[ -f "$dir/${TARGET_ID}.md" ]] && TARGET_FILE="$dir/${TARGET_ID}.md"
        [[ -f "$dir/${SOURCE_ID}.md" ]] && SOURCE_FILE="$dir/${SOURCE_ID}.md"
      done

      if [[ -z "$TARGET_FILE" || -z "$SOURCE_FILE" ]]; then
        echo "ERROR: Entry not found (target=$TARGET_ID source=$SOURCE_ID)." >&2
        exit 1
      fi

      # Merge verified_by from source into target
      SOURCE_VB=$(_fm_get "$SOURCE_FILE" "verified_by")
      TARGET_VB=$(_fm_get "$TARGET_FILE" "verified_by")

      # Parse arrays, merge unique values
      MERGED_VB=$(printf '%s\n%s' "$TARGET_VB" "$SOURCE_VB" | tr -d '[]' | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' | sort -u | paste -sd ',' | sed 's/^/[/;s/$/]/')
      _fm_set "$TARGET_FILE" "verified_by" "$MERGED_VB"

      # Merge verified_in from source into target
      SOURCE_VI=$(_fm_get "$SOURCE_FILE" "verified_in")
      TARGET_VI=$(_fm_get "$TARGET_FILE" "verified_in")

      MERGED_VI=$(printf '%s\n%s' "$TARGET_VI" "$SOURCE_VI" | tr -d '[]' | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' | sort -u | paste -sd ',' | sed 's/^/[/;s/$/]/')
      _fm_set "$TARGET_FILE" "verified_in" "$MERGED_VI"

      # Mark source as deprecated
      _fm_set "$SOURCE_FILE" "status" "deprecated"
      _fm_set "$SOURCE_FILE" "supersedes" "[]"

      echo "Merged $SOURCE_ID -> $TARGET_ID"
      echo "Source marked deprecated."
      ;;

    skip)
      echo "Skipped."
      ;;

    *)
      echo "ERROR: Unknown action: $ACTION_TYPE" >&2
      exit 1
      ;;
  esac

  # Rebuild indexes
  bash "$SCRIPT_DIR/util/index-rebuild.sh" "$FINDINGS_DIR"
  bash "$SCRIPT_DIR/util/index-rebuild.sh" "$WISDOM_DIR"

else
  # Audit mode (default)
  echo "=== HCC Compact Audit ==="
  echo ""

  # 1. Duplicate scan
  echo "--- Potential Duplicates ---"
  DUP_FOUND=0
  declare -a checked_ids=()
  for f in "$FINDINGS_DIR"/*.md; do
    [[ "$(basename "$f")" == "_index.md" ]] && continue
    [[ ! -f "$f" ]] && continue

    f_status=$(_fm_get "$f" "status")
    [[ "$f_status" != "active" ]] && continue

    f_id=$(_fm_get "$f" "id")
    f_type=$(_fm_get "$f" "type")
    f_tags=$(_fm_get "$f" "tags")
    f_title=$(_fm_get "$f" "title")

    # Skip already checked
    for cid in "${checked_ids[@]:-}"; do
      [[ "$cid" == "$f_id" ]] && continue 2
    done

    tags_csv=$(echo "$f_tags" | tr -d '[]' | tr -d '"')
    similar=$(_find_similar_entries "$FINDINGS_DIR" "$f_type" "$tags_csv" 2>/dev/null || true)

    if [[ -n "$similar" ]]; then
      # Filter out self
      other=$(echo "$similar" | grep -v "^${f_id}|" || true)
      if [[ -n "$other" ]]; then
        echo "  $f_id ($f_title)"
        echo "    Similar to: $other"
        DUP_FOUND=1
      fi
    fi
    checked_ids+=("$f_id")
  done
  [[ $DUP_FOUND -eq 0 ]] && echo "  None found."
  echo ""

  # 2. Stale entries
  echo "--- Stale Entries ---"
  STALE_FOUND=0
  for dir in "$FINDINGS_DIR" "$WISDOM_DIR"; do
    for f in "$dir"/*.md; do
      [[ "$(basename "$f")" == "_index.md" ]] && continue
      [[ ! -f "$f" ]] && continue
      f_status=$(_fm_get "$f" "status")
      if [[ "$f_status" == "stale" ]]; then
        f_id=$(_fm_get "$f" "id")
        f_updated=$(_fm_get "$f" "updated_at")
        echo "  $f_id (last updated: $f_updated)"
        STALE_FOUND=1
      fi
    done
  done
  [[ $STALE_FOUND -eq 0 ]] && echo "  None found."
  echo ""

  # 3. Deprecated entries
  echo "--- Deprecated Entries ---"
  DEP_FOUND=0
  for dir in "$FINDINGS_DIR" "$WISDOM_DIR"; do
    for f in "$dir"/*.md; do
      [[ "$(basename "$f")" == "_index.md" ]] && continue
      [[ ! -f "$f" ]] && continue
      f_status=$(_fm_get "$f" "status")
      if [[ "$f_status" == "deprecated" ]]; then
        f_id=$(_fm_get "$f" "id")
        f_supersedes=$(_fm_get "$f" "supersedes")
        echo "  $f_id (supersedes: $f_supersedes)"
        DEP_FOUND=1
      fi
    done
  done
  [[ $DEP_FOUND -eq 0 ]] && echo "  None found."
  echo ""

  echo "Run compact --apply to make changes (requires user confirmation)."
fi
