---
description: Search memory for relevant findings and wisdom. Usage: /hcc-memory:search <keywords>
---

Search project memory for: $ARGUMENTS

Run:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/search.sh" "$(pwd)" "$ARGUMENTS"
```

Display results (max 5). Priority order:
1. wisdom/ active entries
2. findings/ active entries
3. stale entries (marked [stale])

For each result, show: ID, status, validation_level, title, tags, confidence, file path.
Use these markers for validation_level:
- syntax: [syntax]
- numerical: [numerical⚠️] — append note: "convergence verified, physics unverified"
- physical: [physical✓]
- methodology: [methodology✓✓]

If a finding was useful and applied, update its timestamp:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/touch.sh" "$(pwd)" "<id>"
```
