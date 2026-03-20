#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PLUGIN_ROOT/scripts/util/platform.sh"
source "$PLUGIN_ROOT/scripts/util/frontmatter.sh"

setup_with_task() {
  local tmpdir
  tmpdir=$(mktemp -d)
  bash "$PLUGIN_ROOT/scripts/init-memory.sh" "$tmpdir" "openfoam" "" > /dev/null
  bash "$PLUGIN_ROOT/scripts/plan.sh" "$tmpdir" "Test task" > /dev/null
  bash "$PLUGIN_ROOT/scripts/log-trace.sh" "$tmpdir" "Did some work" < /dev/null
  echo "$tmpdir"
}

test_complete_archives_trace() {
  local tmpdir
  tmpdir=$(setup_with_task)
  bash "$PLUGIN_ROOT/scripts/complete.sh" "$tmpdir" "Task done" > /dev/null

  # Session archive should exist
  local session_count
  session_count=$(find "$tmpdir/memory/sessions" -name "S-*.md" 2>/dev/null | wc -l)
  assert_true "[ $session_count -ge 1 ]" "Should have archived session"

  rm -rf "$tmpdir"
}

test_complete_renames_active() {
  local tmpdir
  tmpdir=$(setup_with_task)
  bash "$PLUGIN_ROOT/scripts/complete.sh" "$tmpdir" "Task done" > /dev/null

  # _active.md should be reset to none
  local status
  status=$(_fm_get "$tmpdir/memory/tasks/_active.md" "status")
  assert_equals "none" "$status" "Active task should be none"

  # Archived task file should exist
  local task_archive
  task_archive=$(find "$tmpdir/memory/tasks" -name "T-*.md" 2>/dev/null | head -1)
  assert_true "[ -n '$task_archive' ]" "Archived task file should exist"

  rm -rf "$tmpdir"
}

test_complete_resets_state() {
  local tmpdir
  tmpdir=$(setup_with_task)
  bash "$PLUGIN_ROOT/scripts/complete.sh" "$tmpdir" "Task done" > /dev/null

  local active_task
  active_task=$(_json_get "$tmpdir/.hcc/state.json" "active_task")
  assert_true "[ '$active_task' = 'null' ] || [ -z '$active_task' ]" "active_task should be null"

  local count
  count=$(_json_get "$tmpdir/.hcc/state.json" "action_count")
  assert_equals "0" "$count" "action_count should be 0"

  rm -rf "$tmpdir"
}

test_complete_upgrade() {
  local tmpdir
  tmpdir=$(setup_with_task)

  # Create a finding
  local payload='{"title":"test finding","scope":"domain","type":"EF","layer":"foundation","domain":"openfoam","tags":["test","finding"],"confidence":"medium","validation_level":"syntax","problem":"test problem","action":"test action","contributor":"wei","case_name":"test-case"}'
  bash "$PLUGIN_ROOT/scripts/promote.sh" "$tmpdir" --create "$payload" > /dev/null

  # Find the ID
  local finding_file
  finding_file=$(find "$tmpdir/memory/findings" -name "F-*.md" ! -name "_index.md" | head -1)
  local finding_id
  finding_id=$(_fm_get "$finding_file" "id")

  # Upgrade to wisdom
  bash "$PLUGIN_ROOT/scripts/complete.sh" "$tmpdir" --upgrade "$finding_id" > /dev/null

  # Wisdom entry should exist
  local wisdom_file
  wisdom_file=$(find "$tmpdir/memory/wisdom" -name "W-*.md" ! -name "_index.md" | head -1)
  assert_true "[ -n '$wisdom_file' ]" "Wisdom file should exist"

  # Original finding should be deprecated
  local orig_status
  orig_status=$(_fm_get "$finding_file" "status")
  assert_equals "deprecated" "$orig_status" "Original finding should be deprecated"

  rm -rf "$tmpdir"
}

test_complete_empty_trace_fallback() {
  local tmpdir
  tmpdir=$(mktemp -d)
  bash "$PLUGIN_ROOT/scripts/init-memory.sh" "$tmpdir" "openfoam" "" > /dev/null
  bash "$PLUGIN_ROOT/scripts/plan.sh" "$tmpdir" "Test task" > /dev/null

  # Simulate actions without any trace entries (the bug scenario)
  _json_set "$tmpdir/.hcc/state.json" "action_count" "15"

  local output
  output=$(bash "$PLUGIN_ROOT/scripts/complete.sh" "$tmpdir" "Task done with empty trace" 2>&1)

  # Should warn about empty trace
  assert_match "WARNING" "$output" "Should warn about empty trace"

  # Archived session should contain Recovery entry
  local session_file
  session_file=$(find "$tmpdir/memory/sessions" -name "S-*.md" 2>/dev/null | head -1)
  assert_true "[ -n '$session_file' ]" "Session file should exist"
  assert_file_contains "$session_file" "Recovery" "Should have Recovery entry"
  assert_file_contains "$session_file" "15 actions" "Should mention action count"

  rm -rf "$tmpdir"
}

run_tests test_complete_archives_trace test_complete_renames_active test_complete_resets_state test_complete_upgrade test_complete_empty_trace_fallback
