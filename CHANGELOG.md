# Changelog

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
