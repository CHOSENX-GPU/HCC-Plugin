# Changelog

## [0.2.1] - 2026-03-20

### Bug Fixes
- **Race condition fix**: Replace non-atomic read-modify-write on `state.json` with append-only `.hcc/action_ticks` file — `echo >> file` is atomic on POSIX, so concurrent hooks never lose increments
- **Checkpoint lock**: Use `mkdir`-based portable lock to prevent double-fire when parallel hooks hit the checkpoint boundary simultaneously
- **Stale buffer leak**: `plan.sh` and `complete.sh` now clear all temp files (`action_ticks`, `tool_activity.tmp`, `last_checkpoint.tmp`, `last_turn_count.tmp`) to prevent previous task data bleeding into the next task's first checkpoint
- **Self-counting fix**: `plan.sh` creates a `.hcc/skip_next_count` flag so its own PostToolUse hook invocation is not counted as an action
- `stop-hook.sh` and `session-end-hook.sh` now read count from `action_ticks` (source of truth) instead of `state.json`
- New test: `test_action_counter_parallel_safety` verifies 5 concurrent appends produce count=5
- New test: `test_action_counter_skip_flag` verifies skip flag consumption

## [0.2.0] - 2026-03-20

### Critical Bug Fix
- Fix `pwd` bug in `action-counter.sh` and `session-start.sh`: use `_project_root()` to walk up from `cwd` instead of relying on `$(pwd)`, which silently exited when Bash tools `cd`'d to subdirectories (caused action_count=17 out of 50+ tool calls)

### New Feature: Dual-Layer Auto-Trace
- **Auto-checkpoints**: Hook now auto-writes trace entries every N actions (no Agent cooperation needed), capturing tool names and file paths from PostToolUse stdin JSON
- **Phase protocol**: `log-trace.sh` supports `--phase plan|exec|check|done|error|checkpoint|turn|session_end` for emoji-prefixed structured entries
- **`HCC_NO_INCREMENT=1` env var**: Prevents double-counting when hook calls `log-trace.sh`
- **Stop hook**: Writes turn-end markers with action count (with `stop_hook_active` guard)
- **SessionEnd hook**: Writes session summary and flushes remaining tool activity
- **SessionStart compact**: Re-injects recent trace summary into context after compaction
- **complete.sh fallback**: Warns and reconstructs a Recovery trace entry if trace is empty at task completion
- Updated SKILL.md with Phase Protocol templates and pragmatic hook response guidance
- Updated `commands/log.md` with `--phase` documentation and examples
- Trace header template now includes phase legend

## [0.1.2] - 2026-03-20

- Fix `hooks/hooks.json`: plugin format requires a top-level `"hooks": { ... }` wrapper (not bare `PostToolUse` / `SessionStart` keys). Resolves “expected record, received undefined” on `hooks` path.

## [0.1.1] - 2026-03-20

- Fix `plugin.json`: `author` must be an object `{ "name": "..." }` per Claude Code manifest validation (not a string).

## [0.1.0] - 2026-03-20

- Publish lean plugin repo: omit internal `docs/`, spec, and implementation-prompt sources (see `.gitignore`)
- Add `.claude-plugin/marketplace.json` for standard Claude Code install: `/plugin marketplace add …` then `/plugin install hcc-memory@hcc-plugin`
- Initial MVP release
- Three-layer memory system (trace / findings / wisdom)
- Commands: init, plan, promote, complete, recover, search, status, compact, export
- 5-Action Rule hooks
- Memory workflow skill
