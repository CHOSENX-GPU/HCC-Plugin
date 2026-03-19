#!/usr/bin/env bash
# Restricted YAML front matter read/write.
# Only handles: single-line key: value and key: [a, b, c].
# No nested objects. No multi-line values.

FRONTMATTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$FRONTMATTER_DIR/platform.sh"

_fm_get() {
  local file="$1" key="$2"
  awk -v key="$key" '
    /^---$/ { fm++; next }
    fm == 1 {
      if ($0 ~ "^" key ":") {
        sub("^" key ":[[:space:]]*", "")
        gsub(/^"/, ""); gsub(/"$/, "")
        print
        exit
      }
    }
    fm >= 2 { exit }
  ' "$file"
}

_fm_get_array() {
  local file="$1" key="$2"
  _fm_get "$file" "$key" | tr -d '[]' | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$'
}

_fm_set() {
  local file="$1" key="$2" value="$3"
  if grep -q "^${key}:" "$file" 2>/dev/null; then
    _sed_inplace "s|^${key}:.*|${key}: ${value}|" "$file"
  else
    # Insert new key before the closing --- of front matter
    local tmp
    tmp=$(mktemp)
    local fm_count=0
    local inserted=0
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "$line" == "---" ]]; then
        ((fm_count++))
        if [[ $fm_count -eq 2 && $inserted -eq 0 ]]; then
          echo "${key}: ${value}" >> "$tmp"
          inserted=1
        fi
      fi
      echo "$line" >> "$tmp"
    done < "$file"
    mv "$tmp" "$file"
  fi
}

_fm_keys() {
  local file="$1"
  awk '
    /^---$/ { fm++; next }
    fm == 1 && /^[a-z_]+:/ { sub(/:.*/, ""); print }
    fm >= 2 { exit }
  ' "$file"
}

_fm_get_body() {
  local file="$1"
  awk '
    /^---$/ { fm++; next }
    fm >= 2 { print }
  ' "$file"
}

_fm_count_entries() {
  local dir="$1" status="${2:-}"
  local count=0
  for f in "$dir"/*.md; do
    [[ "$(basename "$f")" == "_index.md" ]] && continue
    [[ ! -f "$f" ]] && continue
    if [[ -n "$status" ]]; then
      local s
      s=$(_fm_get "$f" "status")
      [[ "$s" == "$status" ]] && ((count++)) || true
    else
      ((count++)) || true
    fi
  done
  echo "$count"
}
