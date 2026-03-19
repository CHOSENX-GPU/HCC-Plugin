---
name: memory-workflow
description: "Manages project-level memory using HCC. Activates when: project has memory/ directory,
  encountering errors, making configuration decisions, discovering insights, completing tasks,
  or resuming after a break."
---

# HCC Memory Workflow

You are working in a project with the HCC memory system (memory/ directory exists).

## 5-Action Rule (MANDATORY)
After every 5 tool uses, update the trace:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/log-trace.sh" "$(pwd)" "<brief summary>"
```

This is not optional. Forgetting causes permanent context loss.

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

## When to Suggest /hcc-memory:promote
After solving a non-trivial error, making a configuration choice that required experimentation,
discovering something about physical behavior, or finding a workflow improvement.
ALSO after completing a post-run evaluation that revealed insights about result quality.

## Layer Judgment (during promote)
- Foundation: would this help someone doing a COMPLETELY DIFFERENT type of simulation?
  If yes → foundation.
- Specialist: is this specific to a particular application domain (e.g., turbomachinery,
  chip cooling, external aero)? If yes → specialist, and note the specialist_area.
