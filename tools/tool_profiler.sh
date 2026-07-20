#!/usr/bin/env bash
# ANDRAX 2.0 — Tool Execution Profiler
# Profiles termux-backend/tools/<category>/<tool>.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS="$ROOT/termux-backend/tools"
WRAPPER="$ROOT/bin/andrax-tool-wrapper.sh"

tool_id="${1:-}"
[ -z "$tool_id" ] && { echo "Usage: tool_profiler.sh <tool_id>"; exit 1; }

tool_path=$(find "$TOOLS" -type f -name "$tool_id.sh" | head -n 1)
[ -z "$tool_path" ] && { echo "Tool not found: $tool_id"; exit 1; }

echo "=== ANDRAX Tool Execution Profiler ==="
echo "Tool: $tool_id"
echo "Path: $tool_path"
echo

start=$(date +%s.%N)

# Run tool under wrapper
/usr/bin/time -v bash "$WRAPPER" "$tool_id" 2>&1 | tee /tmp/andrax_tool_profile.log

end=$(date +%s.%N)
elapsed=$(echo "$end - $start" | bc)

echo
echo "--- Summary ---"
echo "Execution time: $elapsed seconds"
echo "Exit code: $?"
echo "Log: /tmp/andrax_tool_profile.log"

echo "=== Profiling Complete ==="
