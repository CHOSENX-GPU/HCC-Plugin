---
description: Audit memory for redundancy and manage stale entries.
---

Run a compact audit of the memory system:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/compact.sh" "$(pwd)"
```

This shows:
1. **Potential duplicates** — entries with matching type and >= 2 overlapping tags
2. **Stale entries** — entries not updated within the threshold
3. **Deprecated entries** — entries superseded by newer versions

For each issue, ask the user what to do:

- **merge_into**: Merge source entry's verified_by/verified_in into target, deprecate source
- **archive**: Mark entry as archived (removed from active use)
- **skip**: Leave as-is

Apply user choices:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/compact.sh" "$(pwd)" --apply '{"action":"<action>","target_id":"<id>","source_id":"<id>"}'
```

IMPORTANT: Never modify body content during compact. Only front matter changes are allowed.
All modifications require explicit user confirmation — compact only generates the report.
