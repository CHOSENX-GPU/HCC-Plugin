#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PLUGIN_ROOT/scripts/util/platform.sh"

setup_with_findings() {
  local tmpdir
  tmpdir=$(mktemp -d)
  bash "$PLUGIN_ROOT/scripts/init-memory.sh" "$tmpdir" "openfoam" "" > /dev/null
  bash "$PLUGIN_ROOT/scripts/plan.sh" "$tmpdir" "Test" > /dev/null

  local payload='{"title":"simpleFoam FPE zero field","scope":"domain","type":"EF","layer":"foundation","domain":"openfoam","tags":["simpleFoam","FPE","initial-conditions"],"confidence":"medium","validation_level":"syntax","problem":"Zero initial field causes floating point exception","action":"Use potentialFoam to generate initial field","contributor":"wei","case_name":"LS89"}'
  bash "$PLUGIN_ROOT/scripts/promote.sh" "$tmpdir" --create "$payload" > /dev/null

  echo "$tmpdir"
}

test_search_finds_by_keyword() {
  local tmpdir
  tmpdir=$(setup_with_findings)
  local output
  output=$(bash "$PLUGIN_ROOT/scripts/search.sh" "$tmpdir" "simpleFoam FPE")
  assert_match "simpleFoam" "$output" "Should find the finding by keyword"
  assert_match "syntax" "$output" "Should show validation level"

  rm -rf "$tmpdir"
}

test_search_no_results() {
  local tmpdir
  tmpdir=$(setup_with_findings)
  local output
  output=$(bash "$PLUGIN_ROOT/scripts/search.sh" "$tmpdir" "completely unrelated")
  assert_match "No results" "$output" "Should report no results"

  rm -rf "$tmpdir"
}

test_touch_updates_timestamp() {
  local tmpdir
  tmpdir=$(setup_with_findings)

  local finding_file
  finding_file=$(find "$tmpdir/memory/findings" -name "F-*.md" ! -name "_index.md" | head -1)

  source "$PLUGIN_ROOT/scripts/util/frontmatter.sh"
  local finding_id
  finding_id=$(_fm_get "$finding_file" "id")

  bash "$PLUGIN_ROOT/scripts/touch.sh" "$tmpdir" "$finding_id"

  local updated
  updated=$(_fm_get "$finding_file" "updated_at")
  local today
  today=$(date -u +"%Y-%m-%d")
  assert_match "$today" "$updated" "updated_at should be today"

  rm -rf "$tmpdir"
}

run_tests test_search_finds_by_keyword test_search_no_results test_touch_updates_timestamp
