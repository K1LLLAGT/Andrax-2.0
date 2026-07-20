#!/usr/bin/env bash
# ANDRAX 2.0 — Workflow Debugger
# Step-through execution + tracing for workflow-engine/workflows/*.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WF_DIR="$ROOT/workflow-engine/workflows"
ENGINE="$ROOT/scripting-engine/engine.sh"

wf_id="${1:-}"
[ -z "$wf_id" ] && { echo "Usage: workflow_debugger.sh <workflow_id>"; exit 1; }

wf_path="$WF_DIR/$wf_id.sh"
[ ! -f "$wf_path" ] && { echo "Workflow not found: $wf_id"; exit 1; }

echo "=== ANDRAX Workflow Debugger ==="
echo "Workflow: $wf_id"
echo "Path: $wf_path"
echo

echo "--- Workflow Source ---"
nl -ba "$wf_path"
echo

echo "--- Debug Trace ---"
set -x
bash "$ENGINE" workflow "$wf_id" --debug
set +x

echo
echo "=== Debug Complete ==="
