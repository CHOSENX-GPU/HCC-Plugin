#!/usr/bin/env bash
# Sensitive data sanitization for HCC Memory entries
# Two-layer approach: deterministic replacements + scan warnings

SANITIZE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SANITIZE_DIR/platform.sh"

_sanitize_file() {
  local src="$1"
  local dst="$2"
  local warnings=0

  cp "$src" "$dst"

  # --- Layer 1: Deterministic replacements ---
  local current_user current_host

  current_user=$(whoami 2>/dev/null || echo "")
  current_host=$(hostname 2>/dev/null || echo "")

  if [[ -n "$current_user" ]]; then
    # Unix home paths
    _sed_inplace "s|/home/${current_user}/|\$HOME/|g" "$dst"
    _sed_inplace "s|/home/${current_user}|\$HOME|g" "$dst"
    # macOS home paths
    _sed_inplace "s|/Users/${current_user}/|\$HOME/|g" "$dst"
    _sed_inplace "s|/Users/${current_user}|\$HOME|g" "$dst"
    # Windows paths
    _sed_inplace "s|C:\\\\Users\\\\${current_user}\\\\|%USERPROFILE%\\\\|g" "$dst"
    _sed_inplace "s|C:\\\\Users\\\\${current_user}|%USERPROFILE%|g" "$dst"
    # Username itself
    _sed_inplace "s|${current_user}|<user>|g" "$dst"
  fi

  if [[ -n "$current_host" ]]; then
    _sed_inplace "s|${current_host}|<hostname>|g" "$dst"
  fi

  # --- Layer 2: Scan-only warnings (do NOT replace) ---
  # Email patterns
  if grep -qE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' "$dst" 2>/dev/null; then
    echo "  WARNING: Email address pattern found in $dst" >&2
    ((warnings++)) || true
  fi

  # IP addresses
  if grep -qE '\b[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\b' "$dst" 2>/dev/null; then
    echo "  WARNING: IP address pattern found in $dst" >&2
    ((warnings++)) || true
  fi

  # Internal domain patterns
  if grep -qiE '\.(internal|local|corp|lan)\b' "$dst" 2>/dev/null; then
    echo "  WARNING: Internal domain pattern found in $dst" >&2
    ((warnings++)) || true
  fi

  # License file paths
  if grep -qiE '(license|LICENSE|\.lic)' "$dst" 2>/dev/null; then
    echo "  WARNING: Possible license reference found in $dst" >&2
    ((warnings++)) || true
  fi

  if [[ $warnings -gt 0 ]]; then
    return 1
  fi
  return 0
}
