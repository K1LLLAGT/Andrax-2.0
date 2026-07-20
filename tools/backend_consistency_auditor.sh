#!/usr/bin/env bash
# ANDRAX 2.0 — backend consistency auditor
# Checks termux-backend/tools layout vs registry and basic invariants.

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="$ROOT/termux-backend/tools"
REG="$ROOT/android-app/src/main/assets/tool_registry.json"

echo "=== ANDRAX 2.0 Backend Consistency Auditor ==="

command -v jq >/dev/null 2>&1 || {
  echo "jq required (pkg install jq)"
  exit 2
}

echo "-- Filesystem tools present --"
find "$TOOLS_DIR" -type f -name '*.sh' | sed "s|$ROOT/||" | sort

echo
echo "-- Registry tools present --"
jq -r '.categories[] | .tools[] | .script' "$REG" 2>/dev/null | sort || echo "Registry missing or invalid."

echo
echo "-- Missing in registry (present on disk, absent in JSON) --"
disk_tools=$(find "$TOOLS_DIR" -type f -name '*.sh' | sed "s|$ROOT/||" | sort)
reg_tools=$(jq -r '.categories[] | .tools[] | .script' "$REG" 2>/dev/null | sort || true)

comm -23 <(printf '%s\n' "$disk_tools") <(printf '%s\n' "$reg_tools" 2>/dev/null || true)

echo
echo "-- Missing on disk (present in JSON, absent on filesystem) --"
comm -13 <(printf '%s\n' "$disk_tools") <(printf '%s\n' "$reg_tools" 2>/dev/null || true)

echo "=== Done ==="
