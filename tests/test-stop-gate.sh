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
  bash "$PLUGIN_ROOT/scripts/plan.sh" "$tmpdir" "Stop gate test task" >/dev/null
  rm -f "$tmpdir/.hcc/skip_next_count"
  echo "$tmpdir"
}

test_stop_gate_blocks_for_promote() {
  local tmpdir
  tmpdir=$(setup_project)

  # Simulate 16 actions (above default threshold of 15)
  for i in $(seq 1 16); do echo "- tick $i" >> "$tmpdir/.hcc/action_ticks"; done

  cd "$tmpdir"
  local output
  output=$(echo '{"stop_hook_active":false,"last_assistant_message":"Working on it..."}' \
    | bash "$PLUGIN_ROOT/scripts/hooks/stop-hook.sh" 2>/dev/null)

  # Should output a block decision
  assert_match "block" "$output" "Should output block decision for promote"
  assert_match "promote" "$output" "Should mention promote in reason"

  # last_promote_count.tmp should be updated
  local lpc
  lpc=$(cat "$tmpdir/.hcc/last_promote_count.tmp" 2>/dev/null | tr -d '[:space:]')
  assert_equals "16" "$lpc" "last_promote_count should be updated to 16"

  rm -rf "$tmpdir"
}

test_stop_gate_skips_when_stop_hook_active() {
  local tmpdir
  tmpdir=$(setup_project)

  for i in $(seq 1 20); do echo "- tick $i" >> "$tmpdir/.hcc/action_ticks"; done

  cd "$tmpdir"
  local output
  output=$(echo '{"stop_hook_active":true,"last_assistant_message":"Done."}' \
    | bash "$PLUGIN_ROOT/scripts/hooks/stop-hook.sh" 2>/dev/null)

  # Should NOT output anything (allow stop)
  assert_equals "" "$output" "Should produce no output when stop_hook_active is true"

  rm -rf "$tmpdir"
}

test_stop_gate_skips_when_recently_promoted() {
  local tmpdir
  tmpdir=$(setup_project)

  for i in $(seq 1 10); do echo "- tick $i" >> "$tmpdir/.hcc/action_ticks"; done
  # Mark that we promoted at count 5 (only 5 new actions, below threshold of 15)
  echo "5" > "$tmpdir/.hcc/last_promote_count.tmp"

  cd "$tmpdir"
  local output
  output=$(echo '{"stop_hook_active":false,"last_assistant_message":"Still working."}' \
    | bash "$PLUGIN_ROOT/scripts/hooks/stop-hook.sh" 2>/dev/null)

  assert_equals "" "$output" "Should not block when recently promoted (below threshold)"

  rm -rf "$tmpdir"
}

test_stop_gate_blocks_for_complete() {
  local tmpdir
  tmpdir=$(setup_project)

  # Few actions (below promote threshold) but completion language detected
  for i in $(seq 1 5); do echo "- tick $i" >> "$tmpdir/.hcc/action_ticks"; done

  cd "$tmpdir"
  local output
  output=$(echo '{"stop_hook_active":false,"last_assistant_message":"All tasks completed. Here is a summary of what was done."}' \
    | bash "$PLUGIN_ROOT/scripts/hooks/stop-hook.sh" 2>/dev/null)

  assert_match "block" "$output" "Should block for complete when completion language detected"
  assert_match "complete" "$output" "Should mention complete in reason"

  # complete_requested.tmp should exist
  assert_true "[ -f '$tmpdir/.hcc/complete_requested.tmp' ]" "complete_requested flag should exist"

  rm -rf "$tmpdir"
}

test_stop_gate_no_block_when_no_task() {
  local tmpdir
  tmpdir=$(mktemp -d)
  bash "$PLUGIN_ROOT/scripts/init-memory.sh" "$tmpdir" "openfoam" "" >/dev/null
  # Create trace but no active task (status is "none")
  cat > "$tmpdir/memory/trace.md" << 'EOF'
# Execution Trace

> Task: (none)
EOF

  for i in $(seq 1 20); do echo "- tick $i" >> "$tmpdir/.hcc/action_ticks"; done

  cd "$tmpdir"
  local output
  output=$(echo '{"stop_hook_active":false,"last_assistant_message":"All finished."}' \
    | bash "$PLUGIN_ROOT/scripts/hooks/stop-hook.sh" 2>/dev/null)

  assert_equals "" "$output" "Should not block when no active task"

  rm -rf "$tmpdir"
}

test_stop_gate_still_writes_turn() {
  local tmpdir
  tmpdir=$(setup_project)

  for i in $(seq 1 3); do echo "- tick $i" >> "$tmpdir/.hcc/action_ticks"; done

  cd "$tmpdir"
  echo '{"stop_hook_active":false,"last_assistant_message":"Working..."}' \
    | bash "$PLUGIN_ROOT/scripts/hooks/stop-hook.sh" >/dev/null 2>/dev/null

  # TURN marker should be written to trace regardless of gate outcome
  assert_file_contains "$tmpdir/memory/trace.md" "TURN" "Should write TURN marker"
  assert_file_contains "$tmpdir/memory/trace.md" "3 actions this turn" "Should show action count in TURN"

  rm -rf "$tmpdir"
}

run_tests test_stop_gate_blocks_for_promote test_stop_gate_skips_when_stop_hook_active test_stop_gate_skips_when_recently_promoted test_stop_gate_blocks_for_complete test_stop_gate_no_block_when_no_task test_stop_gate_still_writes_turn
