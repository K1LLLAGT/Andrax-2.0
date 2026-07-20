#!/usr/bin/env bash
# ANDRAX 2.0 — Workflow Visualizer
# ASCII DAG for workflow steps (shell + YAML)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WF_SH="$ROOT/workflow-engine/workflows"
WF_YAML="$ROOT/workflows"

wf_id="${1:-}"
[ -z "$wf_id" ] && { echo "Usage: workflow_visualizer.sh <workflow_id>"; exit 1; }

# Detect shell workflow
if [ -f "$WF_SH/$wf_id.sh" ]; then
    wf="$WF_SH/$wf_id.sh"
    echo "=== ANDRAX Workflow Visualizer (Shell) ==="
    echo "Workflow: $wf_id"
    echo "Path: $wf"
    echo

    echo "--- Steps (detected via function calls + comments) ---"
    grep -E '^\s*#' "$wf" | sed 's/^# */- /'
    grep -E '^\s*[a-zA-Z0-9_]+\s*\(' "$wf" | sed 's/^/- function: /'
    echo

    echo "--- ASCII DAG ---"
    grep -E '^\s*[a-zA-Z0-9_]+\s*\(' "$wf" | nl -ba | \
        awk '{print "  ["$1"] --> " $2}'
    echo

    exit 0
fi

# Detect YAML workflow
yaml=$(find "$WF_YAML" -type f -name "$wf_id.yaml" | head -n 1)
if [ -n "$yaml" ]; then
    echo "=== ANDRAX Workflow Visualizer (YAML) ==="
    echo "Workflow: $wf_id"
    echo "Path: $yaml"
    echo

    command -v yq >/dev/null 2>&1 || {
        echo "yq required (pkg install yq)"
        exit 2
    }

    echo "--- Steps ---"
    yq e '.steps[] | "- " + .' "$yaml"
    echo

    echo "--- ASCII DAG ---"
    yq e '.steps[]' "$yaml" | nl -ba | awk '{print "  ["$1"] --> " $2}'
    echo

    exit 0
fi

echo "Workflow not found: $wf_id"
