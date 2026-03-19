#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR=$(mktemp -d)

echo "=== Integration Test ==="
echo "Plugin: $PLUGIN_ROOT"
echo "Project: $TMPDIR"
echo ""

# Init
bash "$PLUGIN_ROOT/scripts/init-memory.sh" "$TMPDIR" openfoam turbo > /dev/null
echo "✓ init"

# Plan
bash "$PLUGIN_ROOT/scripts/plan.sh" "$TMPDIR" "Integration test" > /dev/null
echo "✓ plan"

# Log trace
bash "$PLUGIN_ROOT/scripts/log-trace.sh" "$TMPDIR" "Step 1" < /dev/null
bash "$PLUGIN_ROOT/scripts/log-trace.sh" "$TMPDIR" "Step 2" < /dev/null
echo "✓ log-trace (2 entries)"

# Promote
PAYLOAD='{"title":"test FPE","scope":"domain","type":"EF","layer":"foundation","domain":"openfoam","tags":["test","FPE","init"],"confidence":"medium","validation_level":"syntax","problem":"Zero field causes FPE","action":"Use potentialFoam","contributor":"wei","case_name":"LS89"}'
bash "$PLUGIN_ROOT/scripts/promote.sh" "$TMPDIR" --create "$PAYLOAD" > /dev/null
echo "✓ promote"

# Status
echo ""
echo "--- status ---"
bash "$PLUGIN_ROOT/scripts/status.sh" "$TMPDIR"

# Doctor
echo ""
echo "--- doctor ---"
bash "$PLUGIN_ROOT/scripts/doctor.sh" "$TMPDIR"

# Validate
echo ""
echo "--- validate ---"
bash "$PLUGIN_ROOT/scripts/validate.sh" "$TMPDIR"

# Compact
echo ""
echo "--- compact ---"
bash "$PLUGIN_ROOT/scripts/compact.sh" "$TMPDIR"

# Search
echo ""
echo "--- search ---"
bash "$PLUGIN_ROOT/scripts/search.sh" "$TMPDIR" "FPE"

# Recover
echo ""
echo "--- recover (truncated) ---"
bash "$PLUGIN_ROOT/scripts/recover.sh" "$TMPDIR" || true

# Complete
echo ""
echo "--- complete ---"
bash "$PLUGIN_ROOT/scripts/complete.sh" "$TMPDIR" "Done"

echo ""
echo "=== Integration Test PASSED ==="
rm -rf "$TMPDIR"
