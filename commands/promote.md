---
description: Distill valuable learnings from execution trace into structured findings.
---

Promote learnings from the current execution trace.

1. Read memory/trace.md. If empty, say there's nothing to promote.

2. Analyze the trace. Identify entries that contain:
   - Error encounters and solutions → type EF
   - Configuration decisions that worked → type CP
   - Physical insights → type PI
   - Workflow efficiency improvements → type WF
   - Environment/setup fixes → type EV

3. For each learning, propose a structured finding with:
   - Title, Scope (@project or @domain), Type
   - Layer: Is this foundation (applies regardless of application domain)
     or specialist (only applies to a specific application area)?
     Ask yourself: "Would this be useful to someone doing a completely different
     type of simulation?" If yes → foundation. If no → specialist.
   - Validation Level: Ask four progressive questions:
     (a) Did the program run without crashing? → syntax
     (b) Did the solution converge? (residuals, conservation) → numerical
         ⚠️ Always note: "convergence does not guarantee correctness"
     (c) Was result compared against experimental/analytical data? → physical
         Record: what quantity, error range, data source
     (d) Validated across multiple different case types? → methodology
     Most findings start at syntax or numerical. This is normal.
   - Confidence: low/medium/high

4. Ask the user to confirm, modify, or skip each proposal.

5. For confirmed findings, check for duplicates:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/promote.sh" "$(pwd)" --check-dedup "<title>" "<tags>" "<type>"
```

   If duplicates found, present: merge_into / supersede / keep_both / skip.

6. Create the finding:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/promote.sh" "$(pwd)" --create "<json_payload>"
```

   The json_payload must include: title, scope, type, layer, specialist_area, domain, tags, validation_level, confidence, problem, action, contributor, case_name.

7. Rebuild index:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/util/index-rebuild.sh" "$(pwd)/memory/findings"
```
