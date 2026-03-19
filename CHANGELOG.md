# Changelog

## [0.1.0] - 2026-03-20

- Publish lean plugin repo: omit internal `docs/`, spec, and implementation-prompt sources (see `.gitignore`)
- Add `.claude-plugin/marketplace.json` for standard Claude Code install: `/plugin marketplace add …` then `/plugin install hcc-memory@hcc-plugin`
- Initial MVP release
- Three-layer memory system (trace / findings / wisdom)
- Commands: init, plan, promote, complete, recover, search, status, compact, export
- 5-Action Rule hooks
- Memory workflow skill
