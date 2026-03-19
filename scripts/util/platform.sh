#!/usr/bin/env bash
# Cross-platform compatibility layer for HCC Memory

_sed_inplace() {
  if sed --version 2>/dev/null | grep -q GNU; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}

_sha256() {
  if command -v sha256sum &>/dev/null; then
    echo -n "$1" | sha256sum | cut -c1-6
  elif command -v shasum &>/dev/null; then
    echo -n "$1" | shasum -a 256 | cut -c1-6
  else
    echo -n "$1" | cksum | awk '{printf "%06x", $1}' | cut -c1-6
  fi
}

_date_iso() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

_date_short() {
  date -u +"%Y-%m-%d"
}

_stat_size() {
  local file="$1"
  if stat --version 2>/dev/null | grep -q GNU; then
    stat -c%s "$file"
  else
    stat -f%z "$file" 2>/dev/null || wc -c < "$file" | tr -d ' '
  fi
}

_project_root() {
  local dir="$1"
  while [[ "$dir" != "/" && "$dir" != "." ]]; do
    if [[ -d "$dir/memory" ]] || [[ -d "$dir/.hcc" ]]; then
      echo "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

_has_jq() {
  command -v jq &>/dev/null
}

_json_get() {
  local file="$1" key="$2"
  if _has_jq; then
    jq -r ".$key // \"\"" "$file" 2>/dev/null
  else
    # TODO: proper jq fallback
    grep -o "\"$key\"[[:space:]]*:[[:space:]]*[^,}\"]*" "$file" 2>/dev/null | \
      sed "s/\"$key\"[[:space:]]*:[[:space:]]*//" | tr -d '"' | tr -d ' '
  fi
}

_json_set() {
  local file="$1" key="$2" value="$3"
  if _has_jq; then
    local tmp
    tmp=$(mktemp)
    jq ".$key = $value" "$file" > "$tmp" && mv "$tmp" "$file"
  else
    # TODO: proper jq fallback
    _sed_inplace "s/\"$key\"[[:space:]]*:[[:space:]]*[^,}]*/\"$key\": $value/" "$file"
  fi
}
