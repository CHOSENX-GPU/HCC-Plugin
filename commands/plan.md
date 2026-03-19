---
description: Start a new task. Usage: /hcc-memory:plan <task description>
---

Start a new task: $ARGUMENTS

Run:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/plan.sh" "$(pwd)" $ARGUMENTS
```

If an active task exists, ask the user to complete it first or force-start.
After creating the task, display the plan and remind about the 5-Action Rule.
