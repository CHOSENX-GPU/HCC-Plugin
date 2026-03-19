#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/util/platform.sh"
source "$SCRIPT_DIR/util/frontmatter.sh"
source "$SCRIPT_DIR/util/fingerprint.sh"
source "$SCRIPT_DIR/util/dedup.sh"

PROJECT_DIR="$1"
ACTION="$2"

FINDINGS_DIR="$PROJECT_DIR/memory/findings"
WISDOM_DIR="$PROJECT_DIR/memory/wisdom"
CONFIG="$PROJECT_DIR/.hcc/config.yaml"

case "$ACTION" in
  --check-dedup)
    TITLE="${3:-}"
    TAGS="${4:-}"
    TYPE="${5:-}"

    local_found=0
    if [[ -n "$TYPE" && -n "$TAGS" ]]; then
      # Search findings
      if result=$(cd "$FINDINGS_DIR" && _find_similar_entries "$FINDINGS_DIR" "$TYPE" "$TAGS" 2>/dev/null); then
        echo "$result"
        local_found=1
      fi
      # Search wisdom
      if result=$(cd "$WISDOM_DIR" && _find_similar_entries "$WISDOM_DIR" "$TYPE" "$TAGS" 2>/dev/null); then
        echo "$result"
        local_found=1
      fi
    fi

    if [[ $local_found -eq 0 ]]; then
      echo "No duplicates found."
    fi
    ;;

  --create)
    PAYLOAD="$3"

    if ! _has_jq; then
      echo "ERROR: jq is required for --create. Install jq >= 1.6." >&2
      exit 1
    fi

    # Parse JSON payload
    TITLE=$(echo "$PAYLOAD" | jq -r '.title')
    SCOPE=$(echo "$PAYLOAD" | jq -r '.scope // "project"')
    TYPE=$(echo "$PAYLOAD" | jq -r '.type')
    LAYER=$(echo "$PAYLOAD" | jq -r '.layer // "foundation"')
    SPECIALIST_AREA=$(echo "$PAYLOAD" | jq -r '.specialist_area // ""')
    DOMAIN=$(echo "$PAYLOAD" | jq -r '.domain // "general"')
    TAGS=$(echo "$PAYLOAD" | jq -r 'if .tags | type == "array" then .tags | join(", ") else .tags // "" end')
    CONFIDENCE=$(echo "$PAYLOAD" | jq -r '.confidence // "medium"')
    VALIDATION_LEVEL=$(echo "$PAYLOAD" | jq -r '.validation_level // "syntax"')
    PROBLEM=$(echo "$PAYLOAD" | jq -r '.problem // ""')
    ACTION_TEXT=$(echo "$PAYLOAD" | jq -r '.action // ""')
    CONTRIBUTOR=$(echo "$PAYLOAD" | jq -r '.contributor // ""')
    CASE_NAME=$(echo "$PAYLOAD" | jq -r '.case_name // ""')

    # Generate ID
    DOMAIN_CODE=$(_domain_to_code "$DOMAIN")
    ID=$(_generate_id "F" "$DOMAIN_CODE" "$TYPE" "$TITLE")
    ID=$(_check_id_collision "$FINDINGS_DIR" "$ID")

    DATE=$(_date_short)

    # Create finding from template
    TMPL="$SCRIPT_DIR/../templates/finding-entry.md.tmpl"
    OUTFILE="$FINDINGS_DIR/${ID}.md"

    if [[ -f "$TMPL" ]]; then
      sed -e "s|{{ID}}|$ID|g" \
          -e "s|{{TITLE}}|$TITLE|g" \
          -e "s|{{SCOPE}}|$SCOPE|g" \
          -e "s|{{TYPE}}|$TYPE|g" \
          -e "s|{{LAYER}}|$LAYER|g" \
          -e "s|{{SPECIALIST_AREA}}|$SPECIALIST_AREA|g" \
          -e "s|{{DOMAIN}}|$DOMAIN|g" \
          -e "s|{{TAGS}}|$TAGS|g" \
          -e "s|{{DATE}}|$DATE|g" \
          -e "s|{{CONFIDENCE}}|$CONFIDENCE|g" \
          -e "s|{{VALIDATION_LEVEL}}|$VALIDATION_LEVEL|g" \
          -e "s|{{SOLVER}}|$DOMAIN|g" \
          -e "s|{{CONTRIBUTOR}}|$CONTRIBUTOR|g" \
          -e "s|{{CASE_NAME}}|$CASE_NAME|g" \
          -e "s|{{PROBLEM}}|$PROBLEM|g" \
          -e "s|{{ACTION}}|$ACTION_TEXT|g" \
          "$TMPL" > "$OUTFILE"
    else
      echo "ERROR: Template not found: $TMPL" >&2
      exit 1
    fi

    # Rebuild index
    bash "$SCRIPT_DIR/util/index-rebuild.sh" "$FINDINGS_DIR"

    # Update last_promote in state.json
    _json_set "$PROJECT_DIR/.hcc/state.json" "last_promote" "\"$(_date_iso)\""

    echo "Created finding: $ID"
    echo "  File: $OUTFILE"
    echo "  Title: $TITLE"
    ;;

  *)
    echo "Usage: promote.sh <project_dir> --check-dedup <title> <tags> <type>" >&2
    echo "       promote.sh <project_dir> --create <json_payload>" >&2
    exit 1
    ;;
esac
