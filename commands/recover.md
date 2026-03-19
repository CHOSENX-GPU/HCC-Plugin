---
description: Recover context after a session break.
---

Recover context for the current project.

Run:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/recover.sh" "$(pwd)"
```

The script outputs (within configured token budget):
1. Current task plan (tasks/_active.md)
2. Last 10 trace entries
3. findings/_index.md summary
4. wisdom/_index.md summary (if exists)

Present this as a structured briefing. Then ask: "Ready to continue?"
