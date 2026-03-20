---
description: "Log a trace entry. Usage: /hcc-memory:log [--phase plan|exec|check|done|error] <brief description>"
---

Log recent work to the execution trace: $ARGUMENTS

Run:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/log-trace.sh" "$(pwd)" $ARGUMENTS
```

This adds an entry to memory/trace.md with the current timestamp and action number.

### Phase support

Use `--phase` to tag entries with a semantic phase:

- `--phase plan` -- intent, approach, key decisions before starting work
- `--phase exec` -- summary of files modified, commands run, outcomes
- `--phase check` -- simulation/test results, convergence, validation
- `--phase done` -- subtask complete, learnings, promote candidates
- `--phase error` -- error encountered, memory search results, fix applied

### Examples

```
/hcc-memory:log --phase plan "Setting up cavity benchmark: simpleFoam, Re=100"
/hcc-memory:log --phase check "Cavity converged, residuals <1e-6, matches Ghia"
/hcc-memory:log --phase done "Cavity case complete, validated against benchmark"
/hcc-memory:log --phase error "blockMesh failed: non-planar face, fixed vertex coords"
/hcc-memory:log "general note without phase"
```

If the trace exceeds configured limits, oldest entries are automatically archived to memory/sessions/.
