#!/usr/bin/env bash
# ANDRAX 2.0 — fix-permissions
# Makes all core .sh files executable where appropriate.

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== ANDRAX 2.0 Fix Permissions ==="

# Core executable locations
for dir in \
  "$ROOT/bin" \
  "$ROOT/bin/adapters" \
  "$ROOT/launcher" \
  "$ROOT/launcher-system" \
  "$ROOT/scripting-engine" \
  "$ROOT/scripting-engine/scripts" \
  "$ROOT/termux-backend/config" \
  "$ROOT/termux-backend/setup" \
  "$ROOT/termux-backend/tools" \
  "$ROOT/workflow-engine/libs" \
  "$ROOT/workflow-engine/workflows" \
  "$ROOT/tools"
do
  [ -d "$dir" ] || continue
  echo "Dir: $dir"
  find "$dir" -type f -name '*.sh' -exec chmod +x {} \;
done

echo "=== Done ==="
