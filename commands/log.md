---
description: Log a trace entry. Usage: /hcc-memory:log <brief description of recent work>
---

Log recent work to the execution trace: $ARGUMENTS

Run:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/log-trace.sh" "$(pwd)" "$ARGUMENTS"
```

This adds an Action block to memory/trace.md with the current timestamp and action number. The trace provides continuity across sessions and raw material for promoting findings.

If the trace exceeds configured limits, oldest entries are automatically archived to memory/sessions/.
