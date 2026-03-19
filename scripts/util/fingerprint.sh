#!/usr/bin/env bash
# ID generation for HCC Memory entries

FINGERPRINT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$FINGERPRINT_DIR/platform.sh"

_domain_to_code() {
  local domain="${1,,}"
  case "$domain" in
    openfoam) echo "OF" ;;
    su2)      echo "SU2" ;;
    fluent)   echo "FL" ;;
    general)  echo "GEN" ;;
    *)        echo "$(echo "${1^^}" | cut -c1-3)" ;;
  esac
}

_generate_id() {
  local prefix="$1"
  local domain_code="$2"
  local type="$3"
  local title="$4"

  local hash_input="${domain_code,,}|${type}|${title,,}"
  local hash
  hash=$(_sha256 "$hash_input")

  echo "${prefix}-${domain_code}-${type}-${hash}"
}

_check_id_collision() {
  local dir="$1"
  local id="$2"
  local suffix=1
  local candidate="$id"

  while [[ -f "$dir/${candidate}.md" ]]; do
    candidate="${id}-${suffix}"
    ((suffix++))
  done

  echo "$candidate"
}
