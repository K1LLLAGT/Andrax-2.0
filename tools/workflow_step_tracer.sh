#!/usr/bin/env bash
# ANDRAX 2.0 — Workflow Step Tracer

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WF_SH="$ROOT/workflow-engine/workflows"
WF_YAML="$ROOT/workflows"
ENGINE="$ROOT/scripting-engine/engine.sh"

wf_id="${1:-}"
[ -z "$wf_id" ] && { echo "Usage: workflow_step_tracer.sh <workflow_id>"; exit 1; }

echo "=== ANDRAX Workflow Step Tracer ==="
echo "Workflow: $wf_id"
echo

# Shell workflow
if [ -f "$WF_SH/$wf_id.sh" ]; then
    wf="$WF_SH/$wf_id.sh"
    echo "-- Shell workflow: $wf"
    echo

    echo "--- Detected steps (comments + function calls) ---"
    grep -E '^\s*#' "$wf" | sed 's/^# */- /'
    grep -E '^\s*[a-zA-Z0-9_]+\s*\(' "$wf" | sed 's/^/- function: /'
    echo

    echo "--- Live trace ---"
    WF_DEBUG=1 bash "$ENGINE" workflow "$wf_id" --debug
    echo "=== Trace complete ==="
    exit 0
fi

# YAML workflow
yaml=$(find "$WF_YAML" -type f -name "$wf_id.yaml" | head -n 1)
if [ -n "$yaml" ]; then
    echo "-- YAML workflow: $yaml"
    echo

    command -v yq >/dev/null 2>&1 || {
        echo "yq required (pkg install yq)"
        exit 2
    }

    echo "--- Steps ---"
    yq e '.steps[] | "- " + .' "$yaml"
    echo

    echo "--- Live trace (simulated) ---"
    idx=1
    while IFS= read -r step; do
        echo "[step $idx] $step"
        idx=$((idx+1))
        sleep 0.2
    done < <(yq e '.steps[]' "$yaml")
    echo "=== Trace complete ==="
    exit 0
fi

echo "Workflow not found: $wf_id"
