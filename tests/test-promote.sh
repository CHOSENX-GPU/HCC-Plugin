#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

setup_project() {
  local tmpdir
  tmpdir=$(mktemp -d)
  bash "$PLUGIN_ROOT/scripts/init-memory.sh" "$tmpdir" "openfoam" "" > /dev/null
  bash "$PLUGIN_ROOT/scripts/plan.sh" "$tmpdir" "Test task" > /dev/null
  bash "$PLUGIN_ROOT/scripts/log-trace.sh" "$tmpdir" "Found FPE with zero initial field" < /dev/null
  bash "$PLUGIN_ROOT/scripts/log-trace.sh" "$tmpdir" "Fixed by running potentialFoam" < /dev/null
  echo "$tmpdir"
}

test_promote_create_finding() {
  local tmpdir
  tmpdir=$(setup_project)

  local payload='{"title":"simpleFoam FPE with zero field","scope":"domain","type":"EF","layer":"foundation","specialist_area":"","domain":"openfoam","tags":["simpleFoam","divergence","initial-conditions"],"confidence":"medium","validation_level":"syntax","problem":"Initial field all zeros causes floating point exception in simpleFoam","action":"Run potentialFoam first to generate non-zero initial field","contributor":"wei","case_name":"VKI-LS89"}'

  bash "$PLUGIN_ROOT/scripts/promote.sh" "$tmpdir" --create "$payload" > /dev/null

  # Find the created file
  local found
  found=$(find "$tmpdir/memory/findings" -name "F-OF-EF-*.md" ! -name "_index.md" | head -1)
  assert_true "[ -n '$found' ]" "Finding file should exist"

  if [[ -n "$found" ]]; then
    assert_file_contains "$found" "simpleFoam FPE" "Finding contains title"
    assert_file_contains "$found" "schema_version: 1" "Finding has schema_version"
    assert_file_contains "$found" "type: EF" "Finding has type"
    assert_file_contains "$found" "scope: domain" "Finding has scope"
    assert_file_contains "$found" "validation_level: syntax" "Finding has validation_level"
  fi

  # Check index was rebuilt
  assert_file_contains "$tmpdir/memory/findings/_index.md" "EF" "Index contains EF type"

  rm -rf "$tmpdir"
}

test_promote_check_dedup_no_match() {
  local tmpdir
  tmpdir=$(setup_project)

  local output
  output=$(bash "$PLUGIN_ROOT/scripts/promote.sh" "$tmpdir" --check-dedup "something unrelated" "unrelated,tags" "WF" 2>&1)
  assert_match "No duplicates" "$output" "Should report no duplicates"

  rm -rf "$tmpdir"
}

test_promote_check_dedup_with_match() {
  local tmpdir
  tmpdir=$(setup_project)

  # Create a finding first
  local payload='{"title":"simpleFoam FPE","scope":"domain","type":"EF","layer":"foundation","domain":"openfoam","tags":["simpleFoam","FPE","initial-conditions"],"confidence":"medium","validation_level":"syntax","problem":"FPE","action":"potentialFoam","contributor":"wei","case_name":"LS89"}'
  bash "$PLUGIN_ROOT/scripts/promote.sh" "$tmpdir" --create "$payload" > /dev/null

  # Now check for duplicates with matching type and >= 2 common tags
  local output
  output=$(bash "$PLUGIN_ROOT/scripts/promote.sh" "$tmpdir" --check-dedup "similar title" "simpleFoam,FPE,divergence" "EF" 2>&1)
  assert_file_not_contains <(echo "$output") "No duplicates" "Should find a duplicate"

  rm -rf "$tmpdir"
}

run_tests test_promote_create_finding test_promote_check_dedup_no_match test_promote_check_dedup_with_match
