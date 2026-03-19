#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
source "$SCRIPT_DIR/../scripts/util/frontmatter.sh"

test_fm_get_plain() {
  local tmpf
  tmpf=$(mktemp)
  cat > "$tmpf" << 'ENDOFFILE'
---
schema_version: 1
id: F-OF-EF-a13f2c
status: active
---

## Problem
Some content
ENDOFFILE
  assert_equals "1" "$(_fm_get "$tmpf" "schema_version")" "get schema_version"
  assert_equals "F-OF-EF-a13f2c" "$(_fm_get "$tmpf" "id")" "get id"
  assert_equals "active" "$(_fm_get "$tmpf" "status")" "get status"
  rm -f "$tmpf"
}

test_fm_get_quoted() {
  local tmpf
  tmpf=$(mktemp)
  cat > "$tmpf" << 'ENDOFFILE'
---
title: "simpleFoam causes FPE"
tags: [simpleFoam, divergence]
---

Body
ENDOFFILE
  assert_equals "simpleFoam causes FPE" "$(_fm_get "$tmpf" "title")" "get quoted title"
  assert_match "simpleFoam" "$(_fm_get "$tmpf" "tags")" "get tags contains simpleFoam"
  rm -f "$tmpf"
}

test_fm_set_existing() {
  local tmpf
  tmpf=$(mktemp)
  cat > "$tmpf" << 'ENDOFFILE'
---
status: active
updated_at: "2026-01-01"
---

## Body
Content here
ENDOFFILE
  _fm_set "$tmpf" "status" "stale"
  assert_equals "stale" "$(_fm_get "$tmpf" "status")" "set existing key"
  # Verify body not corrupted
  assert_file_contains "$tmpf" "Content here" "body preserved after set"
  rm -f "$tmpf"
}

test_fm_set_new_key() {
  local tmpf
  tmpf=$(mktemp)
  cat > "$tmpf" << 'ENDOFFILE'
---
id: test-id
status: active
---

## Body
ENDOFFILE
  _fm_set "$tmpf" "confidence" "high"
  assert_equals "high" "$(_fm_get "$tmpf" "confidence")" "set new key"
  assert_equals "test-id" "$(_fm_get "$tmpf" "id")" "existing keys preserved"
  assert_file_contains "$tmpf" "## Body" "body preserved after insert"
  rm -f "$tmpf"
}

test_fm_keys() {
  local tmpf
  tmpf=$(mktemp)
  cat > "$tmpf" << 'ENDOFFILE'
---
id: test
status: active
type: EF
---

Body
ENDOFFILE
  local keys
  keys=$(_fm_keys "$tmpf")
  assert_match "id" "$keys" "keys includes id"
  assert_match "status" "$keys" "keys includes status"
  assert_match "type" "$keys" "keys includes type"
  rm -f "$tmpf"
}

test_fm_get_body() {
  local tmpf
  tmpf=$(mktemp)
  cat > "$tmpf" << 'ENDOFFILE'
---
id: test
---

## Problem
Content here
ENDOFFILE
  local body
  body=$(_fm_get_body "$tmpf")
  assert_match "Problem" "$body" "body contains Problem"
  assert_match "Content here" "$body" "body contains content"
  rm -f "$tmpf"
}

run_tests test_fm_get_plain test_fm_get_quoted test_fm_set_existing test_fm_set_new_key test_fm_keys test_fm_get_body
