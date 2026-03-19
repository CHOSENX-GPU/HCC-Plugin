---
description: Initialize HCC memory system in the current project. Creates memory/ directory and configuration.
---

Initialize the HCC memory system for this project.

If the user provided arguments like a domain name, use them. Otherwise ask:
1. What solver/tool does this project use? (openfoam / su2 / fluent / general)
2. What specialist area, if any? (turbomachinery / chip-cooling / external-aero / none)

Then run:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/init-memory.sh" "$(pwd)" "<domain>" "<specialist>"
```

If memory/ already exists, warn the user and ask to confirm before reinitializing.

After initialization, explain the workflow briefly:
- I'll automatically track every 5 tool uses (5-Action Rule)
- Use /hcc-memory:plan to start a task
- Use /hcc-memory:promote when you discover something worth remembering
- Use /hcc-memory:complete when done
- Use /hcc-memory:recover to resume after a break
