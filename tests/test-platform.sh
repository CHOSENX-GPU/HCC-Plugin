#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"
source "$SCRIPT_DIR/../scripts/util/platform.sh"

test_sha256_length() {
  local result
  result=$(_sha256 "openfoam|EF|simpleFoam initial field causes FPE")
  assert_equals "6" "${#result}" "SHA256 hash should be 6 chars"
}

test_sha256_deterministic() {
  local r1 r2
  r1=$(_sha256 "openfoam|EF|simpleFoam initial field causes FPE")
  r2=$(_sha256 "openfoam|EF|simpleFoam initial field causes FPE")
  assert_equals "$r1" "$r2" "SHA256 should be deterministic"
}

test_date_iso() {
  local result
  result=$(_date_iso)
  assert_match "^[0-9]{4}-[0-9]{2}-[0-9]{2}T" "$result" "Date should be ISO format"
}

test_date_short() {
  local result
  result=$(_date_short)
  assert_match "^[0-9]{4}-[0-9]{2}-[0-9]{2}$" "$result" "Date should be YYYY-MM-DD"
}

test_project_root() {
  local tmpdir
  tmpdir=$(mktemp -d)
  mkdir -p "$tmpdir/some/deep/path"
  mkdir -p "$tmpdir/some/memory"
  local result
  result=$(_project_root "$tmpdir/some/deep/path")
  assert_equals "$tmpdir/some" "$result" "_project_root should find memory/ dir"
  rm -rf "$tmpdir"
}

test_json_get_set() {
  local tmpf
  tmpf=$(mktemp)
  echo '{"action_count": 0, "active_task": null}' > "$tmpf"
  local val
  val=$(_json_get "$tmpf" "action_count")
  assert_equals "0" "$val" "json_get action_count"
  _json_set "$tmpf" "action_count" "5"
  val=$(_json_get "$tmpf" "action_count")
  assert_equals "5" "$val" "json_set then json_get"
  rm -f "$tmpf"
}

run_tests test_sha256_length test_sha256_deterministic test_date_iso test_date_short test_project_root test_json_get_set
