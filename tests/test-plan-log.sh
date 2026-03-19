#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PLUGIN_ROOT/scripts/util/platform.sh"

setup_project() {
  local tmpdir
  tmpdir=$(mktemp -d)
  bash "$PLUGIN_ROOT/scripts/init-memory.sh" "$tmpdir" "openfoam" "" >/dev/null
  echo "$tmpdir"
}

test_plan_creates_task() {
  local tmpdir
  tmpdir=$(setup_project)
  bash "$PLUGIN_ROOT/scripts/plan.sh" "$tmpdir" "Run VKI LS89 cascade simulation"

  assert_file_contains "$tmpdir/memory/tasks/_active.md" "Run VKI LS89" "task description in _active.md"
  assert_file_contains "$tmpdir/memory/tasks/_active.md" "status: active" "task status is active"

  rm -rf "$tmpdir"
}

test_plan_reinitializes_trace() {
  local tmpdir
  tmpdir=$(setup_project)
  bash "$PLUGIN_ROOT/scripts/plan.sh" "$tmpdir" "Run LS89"

  assert_file_contains "$tmpdir/memory/trace.md" "Task: Run LS89" "trace header has task"
  assert_file_contains "$tmpdir/memory/trace.md" "Session started:" "trace header has session start"

  rm -rf "$tmpdir"
}

test_plan_resets_state() {
  local tmpdir
  tmpdir=$(setup_project)
  bash "$PLUGIN_ROOT/scripts/plan.sh" "$tmpdir" "Test task"

  source "$PLUGIN_ROOT/scripts/util/platform.sh"
  local active_task
  active_task=$(_json_get "$tmpdir/.hcc/state.json" "active_task")
  assert_equals "Test task" "$active_task" "state.json active_task set"

  local count
  count=$(_json_get "$tmpdir/.hcc/state.json" "action_count")
  assert_equals "0" "$count" "state.json action_count reset"

  rm -rf "$tmpdir"
}

test_plan_blocks_if_active() {
  local tmpdir
  tmpdir=$(setup_project)
  bash "$PLUGIN_ROOT/scripts/plan.sh" "$tmpdir" "Task 1"

  local output exit_code
  output=$(bash "$PLUGIN_ROOT/scripts/plan.sh" "$tmpdir" "Task 2" 2>&1) && exit_code=$? || exit_code=$?

  assert_true "[ $exit_code -ne 0 ]" "Should fail with active task"
  assert_match "[Aa]ctive task" "$output" "Should mention active task"

  rm -rf "$tmpdir"
}

test_log_trace_appends_block() {
  local tmpdir
  tmpdir=$(setup_project)
  bash "$PLUGIN_ROOT/scripts/plan.sh" "$tmpdir" "Test task"

  bash "$PLUGIN_ROOT/scripts/log-trace.sh" "$tmpdir" "Read mesh configuration" </dev/null
  bash "$PLUGIN_ROOT/scripts/log-trace.sh" "$tmpdir" "Set boundary conditions" </dev/null

  assert_file_contains "$tmpdir/memory/trace.md" "Read mesh configuration" "trace has entry 1"
  assert_file_contains "$tmpdir/memory/trace.md" "Set boundary conditions" "trace has entry 2"
  assert_file_contains "$tmpdir/memory/trace.md" "Action-1" "trace has Action-1"
  assert_file_contains "$tmpdir/memory/trace.md" "Action-2" "trace has Action-2"

  rm -rf "$tmpdir"
}

test_log_trace_increments_action_count() {
  local tmpdir
  tmpdir=$(setup_project)
  bash "$PLUGIN_ROOT/scripts/plan.sh" "$tmpdir" "Test task"
  bash "$PLUGIN_ROOT/scripts/log-trace.sh" "$tmpdir" "Action one" </dev/null
  bash "$PLUGIN_ROOT/scripts/log-trace.sh" "$tmpdir" "Action two" </dev/null

  source "$PLUGIN_ROOT/scripts/util/platform.sh"
  local count
  count=$(_json_get "$tmpdir/.hcc/state.json" "action_count")
  assert_equals "2" "$count" "action_count should be 2"

  rm -rf "$tmpdir"
}

test_log_trace_rolling_window() {
  local tmpdir
  tmpdir=$(setup_project)
  bash "$PLUGIN_ROOT/scripts/plan.sh" "$tmpdir" "Test task"

  # Set max entries to 3 for testing
  _sed_inplace "s/trace_max_entries: 30/trace_max_entries: 3/" "$tmpdir/.hcc/config.yaml"

  for i in $(seq 1 6); do
    bash "$PLUGIN_ROOT/scripts/log-trace.sh" "$tmpdir" "Entry $i" </dev/null
  done

  # Should have at most 3 Action blocks
  local count
  count=$(grep -c "^## \[" "$tmpdir/memory/trace.md" || true)
  assert_true "[ $count -le 3 ]" "Rolling window should cap at 3 (got $count)"

  # Latest entry should still be present
  assert_file_contains "$tmpdir/memory/trace.md" "Entry 6" "Should have latest entry"

  # Header should be preserved
  assert_file_contains "$tmpdir/memory/trace.md" "# Execution Trace" "Header preserved"

  # Sessions should have archived blocks
  local session_count
  session_count=$(find "$tmpdir/memory/sessions" -name "S-*.md" 2>/dev/null | wc -l)
  assert_true "[ $session_count -gt 0 ]" "Should have archived sessions"

  rm -rf "$tmpdir"
}

run_tests test_plan_creates_task test_plan_reinitializes_trace test_plan_resets_state test_plan_blocks_if_active test_log_trace_appends_block test_log_trace_increments_action_count test_log_trace_rolling_window
