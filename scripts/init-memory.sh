#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/util/platform.sh"

PROJECT_DIR="$1"
DOMAIN="${2:-general}"
SPECIALIST="${3:-}"

if [[ -d "$PROJECT_DIR/memory" ]]; then
  echo "HCC memory already initialized in this project" >&2
  exit 1
fi

PROJECT_NAME=$(basename "$(cd "$PROJECT_DIR" && pwd)")
DATE=$(_date_iso)

# Create directory structure
mkdir -p "$PROJECT_DIR/memory/findings"
mkdir -p "$PROJECT_DIR/memory/wisdom"
mkdir -p "$PROJECT_DIR/memory/tasks"
mkdir -p "$PROJECT_DIR/memory/sessions"
mkdir -p "$PROJECT_DIR/memory/_export"
mkdir -p "$PROJECT_DIR/memory/knowledge"
mkdir -p "$PROJECT_DIR/.hcc"

touch "$PROJECT_DIR/memory/knowledge/.gitkeep"

# Create empty _active.md (no active task)
cat > "$PROJECT_DIR/memory/tasks/_active.md" << 'EOF'
---
task: ""
started_at: ""
status: none
action_count: 0
---

No active task. Use /hcc-memory:plan to start one.
EOF

# Create trace.md (empty, will be initialized by plan.sh)
cat > "$PROJECT_DIR/memory/trace.md" << EOF
# Execution Trace

> Task: (none)
> Session started: $DATE
EOF

# Create index files
cat > "$PROJECT_DIR/memory/findings/_index.md" << EOF
# Findings Index

> Auto-generated. Do not edit manually.
> Last rebuilt: $DATE

| ID | Type | Title | Status | Confidence | Validation |
|----|------|-------|--------|------------|------------|
EOF

cat > "$PROJECT_DIR/memory/wisdom/_index.md" << EOF
# Wisdom Index

> Auto-generated. Do not edit manually.
> Last rebuilt: $DATE

| ID | Type | Title | Validation |
|----|------|-------|------------|
EOF

# Create config.yaml
SPECIALIST_YAML="[]"
if [[ -n "$SPECIALIST" ]]; then
  SPECIALIST_YAML="[\"$SPECIALIST\"]"
fi

cat > "$PROJECT_DIR/.hcc/config.yaml" << EOF
version: 1
project:
  name: "$PROJECT_NAME"
  domain: "$DOMAIN"
  specialist: $SPECIALIST_YAML
  tags: []

memory:
  flush_interval: 5
  promote_threshold: 15
  trace_max_entries: 30
  trace_max_bytes: 12288
  stale_threshold_days: 180
  recover_budget_bytes: 8192

hub:
  remote: ""
  contributor: ""
  telemetry: false
EOF

# Create state.json
cat > "$PROJECT_DIR/.hcc/state.json" << 'EOF'
{
  "action_count": 0,
  "active_task": null,
  "last_promote": null
}
EOF

# Update .gitignore
GITIGNORE="$PROJECT_DIR/.gitignore"
if [[ ! -f "$GITIGNORE" ]]; then
  touch "$GITIGNORE"
fi

if ! grep -q "# HCC Memory" "$GITIGNORE" 2>/dev/null; then
  cat >> "$GITIGNORE" << 'EOF'

# HCC Memory
memory/trace.md
memory/sessions/
memory/_export/
memory/knowledge/
.hcc/state.json
EOF
fi

echo "HCC Memory initialized in $PROJECT_DIR"
echo "  Domain: $DOMAIN"
echo "  Specialist: ${SPECIALIST:-none}"
echo "  Config: .hcc/config.yaml"
