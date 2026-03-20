---
name: memory-workflow
description: "Manages project-level memory using HCC. Activates when: project has memory/ directory,
  encountering errors, making configuration decisions, discovering insights, completing tasks,
  or resuming after a break."
---

# HCC Memory Workflow

You are working in a project with the HCC memory system (memory/ directory exists).

## 5-Action Rule (Auto-Trace)

The action-counter hook automatically logs a checkpoint trace entry every 5 tool uses.
These auto-checkpoints capture which tools were used (file paths, commands) so the trace
is never empty, even in high-density autonomous workflows.

## Responding to 5-Action Rule Reminders

When you see:
```
📝 [HCC] Auto-logged trace (actions X-Y). Add detail: /hcc-memory:log
```

You SHOULD (but are not blocked if you don't):
1. Briefly note what you accomplished in actions X-Y
2. Run: `/hcc-memory:log "<your 1-sentence summary>"`

The auto-entry ensures trace is never empty. Your manual entry adds meaningful context.
If you're in a high-density workflow, it's OK to skip manual logging -- the auto-entries
provide a baseline timeline.

## Phase Protocol (Enriching Auto-Trace)

Auto-checkpoints record WHAT tools you used. Phase entries record WHY and WHAT YOU LEARNED.
Both are needed for useful promote material.

### PLAN (before starting a subtask)
```bash
/hcc-memory:log --phase plan "Intent: ..., Approach: ..., Risk: ..."
```

### EXEC (after a block of work) -- optional, auto-checkpoints cover basics
```bash
/hcc-memory:log --phase exec "Modified: ..., Ran: ..., Result: ..."
```

### CHECK (after simulation/test/validation)
```bash
/hcc-memory:log --phase check "Convergence: ..., Physical: ..., Quantitative: ..."
```

### DONE (subtask/task complete)
```bash
/hcc-memory:log --phase done "Outcome: ..., Learned: ..., Promote candidate: ..."
```

### ERROR (error encountered)
```bash
/hcc-memory:log --phase error "Error: ..., Memory search: ..., Fix: ..., Root cause: ..."
```

## When You Encounter an Error
BEFORE trying to fix it yourself:
1. Search memory:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/search.sh" "$(pwd)" "<error keywords>"
```

2. If match found, read and apply it. Then mark usage:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/touch.sh" "$(pwd)" "<id>"
```

3. If no match, solve it yourself. Then suggest /hcc-memory:promote.

## Memory Priority (when multiple results)
1. wisdom/ entries (triple-verified, highest authority)
2. findings/ active entries (project experience)
3. findings/ stale entries (may be outdated)
Prefer the entry with more specific applicability matching current situation.

## Validation Level Awareness (CRITICAL)
When you search memory and find a result, CHECK its validation_level:
- `syntax`: This fix stopped an error. Safe to apply for the same error.
- `numerical`: This config achieved convergence. ⚠️ ALWAYS tell the user:
  "This configuration was verified for numerical convergence only, not for
  physical correctness. Consider comparing results against experimental data
  or a known benchmark after applying."
- `physical`: This was validated against external data. Higher confidence.
- `methodology`: Cross-case validated approach. Highest confidence.

NEVER treat a numerical-level finding as if it were physical-level.
The most dangerous Agent is one that confidently applies configurations
that "converge nicely" but produce wrong physics.

## After a Simulation Completes
Do NOT just check "did it finish without error." Also evaluate:
1. **Convergence quality**: Are residuals truly converged or just oscillating?
   Are conservation errors acceptable? Did any monitors plateau?
2. **Physical plausibility**: Do the results make qualitative sense?
   Is there flow where expected? Are magnitudes reasonable?
3. **Quantitative validation** (if reference data available):
   Compare key quantities against experimental/analytical benchmarks.
   Record what was compared, the error range, and the data source.

These post-run evaluations are the raw material for physical-level memories.
Suggest /hcc-memory:promote if any significant findings emerge from this evaluation.

## Automatic Promote and Complete

The Stop hook automatically blocks you from finishing when:
- You have accumulated 15+ actions without promoting findings
- Your task appears complete but you haven't run /hcc-memory:complete

When blocked, follow the instruction in the reason message. This ensures
findings are captured and tasks are properly archived, even in high-density
autonomous workflows.

You can also run these commands proactively at any time:
- /hcc-memory:promote -- after solving errors, making config decisions, or discovering insights
- /hcc-memory:complete "<summary>" -- when your current task is done

## Layer Judgment (during promote)
- Foundation: would this help someone doing a COMPLETELY DIFFERENT type of simulation?
  If yes → foundation.
- Specialist: is this specific to a particular application domain (e.g., turbomachinery,
  chip cooling, external aero)? If yes → specialist, and note the specialist_area.
