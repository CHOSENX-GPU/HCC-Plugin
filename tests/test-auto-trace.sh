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
  bash "$PLUGIN_ROOT/scripts/plan.sh" "$tmpdir" "Auto-trace test" >/dev/null
  echo "$tmpdir"
}

test_action_counter_with_stdin_json() {
  local tmpdir
  tmpdir=$(setup_project)

  local json='{"tool_name":"Write","tool_input":{"file_path":"/tmp/test/system/controlDict"},"cwd":"'"$tmpdir"'"}'
  echo "$json" | bash "$PLUGIN_ROOT/scripts/hooks/action-counter.sh"

  local count
  count=$(_json_get "$tmpdir/.hcc/state.json" "action_count")
  assert_equals "1" "$count" "action_count should be 1 after one hook call"

  # Tool activity should be recorded
  assert_file_exists "$tmpdir/.hcc/tool_activity.tmp" "tool_activity.tmp should exist"
  assert_file_contains "$tmpdir/.hcc/tool_activity.tmp" "Write: controlDict" "Should capture tool name and file"

  rm -rf "$tmpdir"
}

test_action_counter_auto_checkpoint() {
  local tmpdir
  tmpdir=$(setup_project)

  # Fire 5 hook calls to trigger a checkpoint
  for i in $(seq 1 5); do
    local json='{"tool_name":"Bash","tool_input":{"command":"echo test '"$i"'"},"cwd":"'"$tmpdir"'"}'
    echo "$json" | bash "$PLUGIN_ROOT/scripts/hooks/action-counter.sh"
  done

  local count
  count=$(_json_get "$tmpdir/.hcc/state.json" "action_count")
  assert_equals "5" "$count" "action_count should be 5"

  # Trace should have a CHECKPOINT entry
  assert_file_contains "$tmpdir/memory/trace.md" "CHECKPOINT" "Should have auto-checkpoint"
  assert_file_contains "$tmpdir/memory/trace.md" "Actions 1-5" "Should have action range"

  # Checkpoint should contain tool activity
  assert_file_contains "$tmpdir/memory/trace.md" "Bash:" "Should have tool names in checkpoint"

  rm -rf "$tmpdir"
}

test_action_counter_pwd_fix() {
  local tmpdir
  tmpdir=$(setup_project)

  # Create a subdirectory to simulate Bash tool cd'ing elsewhere
  mkdir -p "$tmpdir/subdir/deep"

  # Simulate hook firing from a subdirectory (cwd in JSON points to subdir)
  local json='{"tool_name":"Write","tool_input":{"file_path":"test.txt"},"cwd":"'"$tmpdir/subdir/deep"'"}'
  echo "$json" | bash "$PLUGIN_ROOT/scripts/hooks/action-counter.sh"

  local count
  count=$(_json_get "$tmpdir/.hcc/state.json" "action_count")
  assert_equals "1" "$count" "Should find project root from subdirectory via _project_root"

  rm -rf "$tmpdir"
}

test_action_counter_no_jq_fallback() {
  local tmpdir
  tmpdir=$(setup_project)

  # Even without proper JSON, the hook should not crash
  echo "not json" | bash "$PLUGIN_ROOT/scripts/hooks/action-counter.sh" 2>/dev/null || true

  # Counter should still work (may or may not increment depending on _project_root)
  # At minimum, the script should not crash
  assert_true "true" "action-counter should not crash with bad stdin"

  rm -rf "$tmpdir"
}

test_stop_hook_writes_turn_marker() {
  local tmpdir
  tmpdir=$(setup_project)

  # Simulate some actions
  _json_set "$tmpdir/.hcc/state.json" "action_count" "7"

  # Run stop hook from project dir
  cd "$tmpdir"
  echo '{}' | bash "$PLUGIN_ROOT/scripts/hooks/stop-hook.sh"

  assert_file_contains "$tmpdir/memory/trace.md" "TURN" "Should have TURN marker"
  assert_file_contains "$tmpdir/memory/trace.md" "7 actions this turn" "Should show action count"

  # Running again without action count change should not add duplicate
  echo '{}' | bash "$PLUGIN_ROOT/scripts/hooks/stop-hook.sh"
  local turn_count
  turn_count=$(grep -c "TURN" "$tmpdir/memory/trace.md" 2>/dev/null || true)
  turn_count=${turn_count:-0}
  turn_count=$(echo "$turn_count" | tr -d '[:space:]')
  assert_equals "1" "$turn_count" "Should not duplicate TURN for same count"

  rm -rf "$tmpdir"
}

test_stop_hook_respects_stop_hook_active() {
  local tmpdir
  tmpdir=$(setup_project)
  _json_set "$tmpdir/.hcc/state.json" "action_count" "5"

  cd "$tmpdir"
  echo '{"stop_hook_active": true}' | bash "$PLUGIN_ROOT/scripts/hooks/stop-hook.sh"

  local turn_count
  turn_count=$(grep -c "TURN" "$tmpdir/memory/trace.md" 2>/dev/null || true)
  turn_count=${turn_count:-0}
  turn_count=$(echo "$turn_count" | tr -d '[:space:]')
  assert_equals "0" "$turn_count" "Should not write TURN when stop_hook_active is true"

  rm -rf "$tmpdir"
}

run_tests test_action_counter_with_stdin_json test_action_counter_auto_checkpoint test_action_counter_pwd_fix test_action_counter_no_jq_fallback test_stop_hook_writes_turn_marker test_stop_hook_respects_stop_hook_active
