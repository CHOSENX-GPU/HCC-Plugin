---
description: Complete the current task. Archives trace, reviews findings for wisdom upgrade. Usage: /hcc-memory:complete <summary>
---

Complete the current task: $ARGUMENTS

1. Run:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/complete.sh" "$(pwd)" "$ARGUMENTS"
```

2. The script outputs active findings as `id|type|validation_level|verified_in_count`.
   Scan these for L3 upgrade candidates. A finding qualifies if ANY:
   - verified_in has >= 2 different cases
   - verified_in >= 1 case AND Evidence cites external reference
   - Type WF, used multiple times, no known_failures
   - Type PI, has simulation + literature dual evidence

   ADDITIONALLY, check minimum validation_level for the type:
   - EF (error-fix): minimum syntax (error gone = fix works)
   - CP (config pattern): minimum numerical, strongly recommended physical
     ⚠️ A config that "only converges but isn't verified correct" should NOT
     enter wisdom — it creates false confidence for future users
   - PI (physical insight): MUST be physical (no physical validation = just a guess)
   - WF (workflow): minimum numerical
   - EV (environment): minimum syntax

3. For each candidate, ask user to confirm upgrade.

4. Execute confirmed upgrades:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/complete.sh" "$(pwd)" --upgrade "<finding_id>"
```

5. Display summary: tasks completed, findings created this session, wisdom entries added.
