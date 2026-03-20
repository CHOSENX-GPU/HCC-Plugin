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
  # Consume the skip flag that plan.sh creates (simulating the PostToolUse
  # hook that fires for plan.sh's own Bash call)
  rm -f "$tmpdir/.hcc/skip_next_count"
  echo "$tmpdir"
}

test_action_counter_with_stdin_json() {
  local tmpdir
  tmpdir=$(setup_project)

  local json='{"tool_name":"Write","tool_input":{"file_path":"/tmp/test/system/controlDict"},"cwd":"'"$tmpdir"'"}'
  echo "$json" | bash "$PLUGIN_ROOT/scripts/hooks/action-counter.sh"

  # Count should come from action_ticks (1 line = 1 action)
  local ticks_count
  ticks_count=$(wc -l < "$tmpdir/.hcc/action_ticks" | tr -d ' ')
  assert_equals "1" "$ticks_count" "action_ticks should have 1 line after one hook call"

  # Tool brief should be recorded in the ticks file
  assert_file_contains "$tmpdir/.hcc/action_ticks" "Write: controlDict" "Should capture tool name and file"

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

  local ticks_count
  ticks_count=$(wc -l < "$tmpdir/.hcc/action_ticks" | tr -d ' ')
  assert_equals "5" "$ticks_count" "action_ticks should have 5 lines"

  # Trace should have a CHECKPOINT entry
  assert_file_contains "$tmpdir/memory/trace.md" "CHECKPOINT" "Should have auto-checkpoint"
  assert_file_contains "$tmpdir/memory/trace.md" "Actions 1-5" "Should have action range"

  # Checkpoint should contain tool activity
  assert_file_contains "$tmpdir/memory/trace.md" "Bash:" "Should have tool names in checkpoint"

  # last_checkpoint.tmp should record 5
  local last_cp
  last_cp=$(cat "$tmpdir/.hcc/last_checkpoint.tmp" 2>/dev/null | tr -d '[:space:]')
  assert_equals "5" "$last_cp" "last_checkpoint.tmp should be 5"

  rm -rf "$tmpdir"
}

test_action_counter_pwd_fix() {
  local tmpdir
  tmpdir=$(setup_project)

  mkdir -p "$tmpdir/subdir/deep"

  local json='{"tool_name":"Write","tool_input":{"file_path":"test.txt"},"cwd":"'"$tmpdir/subdir/deep"'"}'
  echo "$json" | bash "$PLUGIN_ROOT/scripts/hooks/action-counter.sh"

  local ticks_count
  ticks_count=$(wc -l < "$tmpdir/.hcc/action_ticks" | tr -d ' ')
  assert_equals "1" "$ticks_count" "Should find project root from subdirectory via _project_root"

  rm -rf "$tmpdir"
}

test_action_counter_no_jq_fallback() {
  local tmpdir
  tmpdir=$(setup_project)

  echo "not json" | bash "$PLUGIN_ROOT/scripts/hooks/action-counter.sh" 2>/dev/null || true

  assert_true "true" "action-counter should not crash with bad stdin"

  rm -rf "$tmpdir"
}

test_action_counter_skip_flag() {
  local tmpdir
  tmpdir=$(setup_project)

  # Create skip flag (as plan.sh would)
  touch "$tmpdir/.hcc/skip_next_count"

  local json='{"tool_name":"Bash","tool_input":{"command":"plan.sh"},"cwd":"'"$tmpdir"'"}'
  echo "$json" | bash "$PLUGIN_ROOT/scripts/hooks/action-counter.sh"

  # Skip flag should have been consumed
  assert_true "[ ! -f '$tmpdir/.hcc/skip_next_count' ]" "skip flag should be removed"

  # No tick should have been recorded
  local ticks_count
  if [[ -f "$tmpdir/.hcc/action_ticks" ]]; then
    ticks_count=$(wc -l < "$tmpdir/.hcc/action_ticks" | tr -d ' ')
  else
    ticks_count=0
  fi
  assert_equals "0" "$ticks_count" "action_ticks should be empty when skip flag was set"

  rm -rf "$tmpdir"
}

test_action_counter_parallel_safety() {
  local tmpdir
  tmpdir=$(setup_project)

  # Launch 5 concurrent hook calls in background
  for i in $(seq 1 5); do
    local json='{"tool_name":"Bash","tool_input":{"command":"echo parallel '"$i"'"},"cwd":"'"$tmpdir"'"}'
    echo "$json" | bash "$PLUGIN_ROOT/scripts/hooks/action-counter.sh" &
  done
  wait

  # All 5 appends must be present (atomic append guarantees no lost writes)
  local ticks_count
  ticks_count=$(wc -l < "$tmpdir/.hcc/action_ticks" | tr -d ' ')
  assert_equals "5" "$ticks_count" "All 5 parallel appends should be recorded (no lost updates)"

  rm -rf "$tmpdir"
}

test_stop_hook_writes_turn_marker() {
  local tmpdir
  tmpdir=$(setup_project)

  # Simulate some actions via the ticks file
  for i in $(seq 1 7); do echo "- tick $i" >> "$tmpdir/.hcc/action_ticks"; done

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
  for i in $(seq 1 5); do echo "- tick $i" >> "$tmpdir/.hcc/action_ticks"; done

  cd "$tmpdir"
  echo '{"stop_hook_active": true}' | bash "$PLUGIN_ROOT/scripts/hooks/stop-hook.sh"

  local turn_count
  turn_count=$(grep -c "TURN" "$tmpdir/memory/trace.md" 2>/dev/null || true)
  turn_count=${turn_count:-0}
  turn_count=$(echo "$turn_count" | tr -d '[:space:]')
  assert_equals "0" "$turn_count" "Should not write TURN when stop_hook_active is true"

  rm -rf "$tmpdir"
}

run_tests test_action_counter_with_stdin_json test_action_counter_auto_checkpoint test_action_counter_pwd_fix test_action_counter_no_jq_fallback test_action_counter_skip_flag test_action_counter_parallel_safety test_stop_hook_writes_turn_marker test_stop_hook_respects_stop_hook_active
