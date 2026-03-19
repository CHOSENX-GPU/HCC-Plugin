#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/util/platform.sh"
source "$SCRIPT_DIR/util/frontmatter.sh"

PROJECT_DIR="$1"
CONFIG="$PROJECT_DIR/.hcc/config.yaml"

BUDGET=$(grep "recover_budget_bytes:" "$CONFIG" 2>/dev/null | awk '{print $2}')
BUDGET=${BUDGET:-8192}

ACTIVE="$PROJECT_DIR/memory/tasks/_active.md"
TRACE="$PROJECT_DIR/memory/trace.md"
F_INDEX="$PROJECT_DIR/memory/findings/_index.md"
W_INDEX="$PROJECT_DIR/memory/wisdom/_index.md"

TOTAL_BYTES=0

_emit_section() {
  local label="$1" file="$2"
  if [[ ! -f "$file" ]]; then return; fi

  local content
  content=$(cat "$file")
  local size=${#content}

  if [[ $((TOTAL_BYTES + size)) -gt $BUDGET ]]; then
    # Truncate to fit budget
    local remaining=$((BUDGET - TOTAL_BYTES))
    if [[ $remaining -le 100 ]]; then return; fi
    content="${content:0:$remaining}..."
    size=$remaining
  fi

  echo "--- $label ($file) ---"
  echo "$content"
  echo ""
  TOTAL_BYTES=$((TOTAL_BYTES + size + 50))
}

_emit_trace_tail() {
  if [[ ! -f "$TRACE" ]]; then return; fi

  echo "--- Recent Trace (last 10 actions) ($TRACE) ---"

  # Extract last 10 Action blocks
  local block_count
  block_count=$(grep -c "^## \[" "$TRACE" 2>/dev/null || echo "0")

  if [[ "$block_count" -le 10 ]]; then
    cat "$TRACE"
  else
    # Header
    awk '/^## \[/{exit} {print}' "$TRACE"
    echo ""
    # Last 10 blocks
    local skip=$((block_count - 10))
    awk -v skip="$skip" '
      /^## \[/ { block++ }
      block > skip { print }
    ' "$TRACE"
  fi

  local trace_size
  trace_size=$(_stat_size "$TRACE")
  TOTAL_BYTES=$((TOTAL_BYTES + trace_size + 50))
  echo ""
}

echo "=== HCC Context Recovery ==="
echo ""

# Priority 1: Active task
_emit_section "Active Task" "$ACTIVE"

# Priority 2: Last 10 trace entries
if [[ $TOTAL_BYTES -lt $BUDGET ]]; then
  _emit_trace_tail
fi

# Priority 3: Findings index
if [[ $TOTAL_BYTES -lt $BUDGET ]]; then
  _emit_section "Findings Index" "$F_INDEX"
fi

# Priority 4: Wisdom index (if budget allows)
if [[ $TOTAL_BYTES -lt $BUDGET ]]; then
  _emit_section "Wisdom Index" "$W_INDEX"
fi

echo "---"
echo "Ready to continue?"
