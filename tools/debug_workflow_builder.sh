#!/usr/bin/env bash
# ANDRAX 2.0 — Workflow Registry Debugger
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WF_SH_DIR="$ROOT/workflow-engine/workflows"
WF_YAML_DIR="$ROOT/workflows"
OUT_DIR="$ROOT/android-app/src/main/assets"
OUT="$OUT_DIR/workflow_registry.json"

echo "=== ANDRAX Workflow Registry Debugger ==="
echo "ROOT: $ROOT"
echo "WF_SH_DIR: $WF_SH_DIR"
echo "WF_YAML_DIR: $WF_YAML_DIR"
echo "OUT_DIR: $OUT_DIR"
echo

echo "--- Checking shell workflows (.sh) ---"
find "$WF_SH_DIR" -type f -name '*.sh' -print || echo "(none found)"
echo

echo "--- Checking YAML workflows (.yaml) ---"
find "$WF_YAML_DIR" -type f -name '*.yaml' -print || echo "(none found)"
echo

echo "--- Testing readability ---"
while IFS= read -r f; do
    if [ -r "$f" ]; then
        echo "OK: $f"
    else
        echo "UNREADABLE: $f"
    fi
done < <(find "$WF_SH_DIR" "$WF_YAML_DIR" -type f \( -name '*.sh' -o -name '*.yaml' \))
echo

echo "--- Ensuring output directory exists ---"
mkdir -p "$OUT_DIR"
ls -ld "$OUT_DIR"
echo

echo "--- Attempting to write test file ---"
echo '{ "test": true }' > "$OUT"
ls -l "$OUT"
echo

echo "=== Debug complete ==="
