---
description: Export domain-scoped findings for knowledge base contribution.
---

Export qualified entries from memory for knowledge base contribution.

Run:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/export.sh" "$(pwd)"
```

Or export a single entry:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/export.sh" "$(pwd)" --id "<entry_id>"
```

Export eligibility:
- scope must be `domain` (project-scoped entries stay local)
- status must be `active`
- Type-specific validation thresholds:
  | Type | Min Validation | Rationale |
  |------|---------------|-----------|
  | EF | numerical | Error fix at least converges |
  | CP | physical | Config must be physically validated |
  | PI | physical | Physical insight needs physical evidence |
  | WF | methodology | Workflow needs cross-case validation |
  | EV | syntax | Environment fix just needs to work |
- `## Evidence` and `## Failure Boundary` sections must be non-empty

Exported files are sanitized (paths, usernames removed) and placed in `memory/_export/`.
Review flagged entries that had sanitization warnings before sharing.
