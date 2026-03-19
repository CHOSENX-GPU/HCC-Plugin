#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

test_init_creates_structure() {
  local tmpdir
  tmpdir=$(mktemp -d)
  bash "$PLUGIN_ROOT/scripts/init-memory.sh" "$tmpdir" "openfoam" "turbomachinery"

  assert_dir_exists "$tmpdir/memory" "memory/"
  assert_dir_exists "$tmpdir/memory/findings" "memory/findings/"
  assert_dir_exists "$tmpdir/memory/wisdom" "memory/wisdom/"
  assert_dir_exists "$tmpdir/memory/tasks" "memory/tasks/"
  assert_dir_exists "$tmpdir/memory/sessions" "memory/sessions/"
  assert_dir_exists "$tmpdir/memory/_export" "memory/_export/"
  assert_dir_exists "$tmpdir/memory/knowledge" "memory/knowledge/"
  assert_file_exists "$tmpdir/memory/trace.md" "trace.md"
  assert_file_exists "$tmpdir/memory/findings/_index.md" "findings/_index.md"
  assert_file_exists "$tmpdir/memory/wisdom/_index.md" "wisdom/_index.md"
  assert_file_exists "$tmpdir/memory/tasks/_active.md" "_active.md"
  assert_file_exists "$tmpdir/.hcc/config.yaml" "config.yaml"
  assert_file_exists "$tmpdir/.hcc/state.json" "state.json"
  assert_file_exists "$tmpdir/memory/knowledge/.gitkeep" ".gitkeep"

  rm -rf "$tmpdir"
}

test_init_config_content() {
  local tmpdir
  tmpdir=$(mktemp -d)
  bash "$PLUGIN_ROOT/scripts/init-memory.sh" "$tmpdir" "openfoam" "turbomachinery"

  assert_file_contains "$tmpdir/.hcc/config.yaml" 'domain: "openfoam"' "config domain"
  assert_file_contains "$tmpdir/.hcc/config.yaml" "turbomachinery" "config specialist"

  rm -rf "$tmpdir"
}

test_init_state_json() {
  local tmpdir
  tmpdir=$(mktemp -d)
  bash "$PLUGIN_ROOT/scripts/init-memory.sh" "$tmpdir" "general" ""

  assert_file_contains "$tmpdir/.hcc/state.json" '"action_count": 0' "state action_count"
  assert_file_contains "$tmpdir/.hcc/state.json" '"active_task": null' "state active_task"
  assert_file_contains "$tmpdir/.hcc/state.json" '"last_promote": null' "state last_promote"

  rm -rf "$tmpdir"
}

test_init_duplicate_fails() {
  local tmpdir
  tmpdir=$(mktemp -d)
  bash "$PLUGIN_ROOT/scripts/init-memory.sh" "$tmpdir" "general" ""

  local output exit_code
  output=$(bash "$PLUGIN_ROOT/scripts/init-memory.sh" "$tmpdir" "general" "" 2>&1) && exit_code=$? || exit_code=$?

  assert_true "[ $exit_code -ne 0 ]" "Duplicate init should fail"
  assert_match "already" "$output" "Should mention already initialized"

  rm -rf "$tmpdir"
}

test_init_gitignore() {
  local tmpdir
  tmpdir=$(mktemp -d)
  echo "*.pyc" > "$tmpdir/.gitignore"
  bash "$PLUGIN_ROOT/scripts/init-memory.sh" "$tmpdir" "general" ""

  assert_file_contains "$tmpdir/.gitignore" "memory/trace.md" ".gitignore has trace"
  assert_file_contains "$tmpdir/.gitignore" ".hcc/state.json" ".gitignore has state"
  assert_file_contains "$tmpdir/.gitignore" "*.pyc" ".gitignore preserves existing"

  rm -rf "$tmpdir"
}

test_init_gitignore_no_duplicate() {
  local tmpdir
  tmpdir=$(mktemp -d)
  bash "$PLUGIN_ROOT/scripts/init-memory.sh" "$tmpdir" "general" ""
  # Simulate re-run of gitignore logic by removing memory/ and re-init
  rm -rf "$tmpdir/memory" "$tmpdir/.hcc"
  bash "$PLUGIN_ROOT/scripts/init-memory.sh" "$tmpdir" "general" ""

  local count
  count=$(grep -c "# HCC Memory" "$tmpdir/.gitignore")
  assert_equals "1" "$count" "HCC Memory marker should appear exactly once"

  rm -rf "$tmpdir"
}

run_tests test_init_creates_structure test_init_config_content test_init_state_json test_init_duplicate_fails test_init_gitignore test_init_gitignore_no_duplicate
