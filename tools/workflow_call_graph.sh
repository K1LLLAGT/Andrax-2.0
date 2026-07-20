#!/usr/bin/env bash
# ANDRAX 2.0 — Workflow → Tool Call Graph Generator

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WF_SH="$ROOT/workflow-engine/workflows"
WF_YAML="$ROOT/workflows"
TOOLS="$ROOT/termux-backend/tools"

echo "=== ANDRAX Workflow → Tool Call Graph ==="

# Collect tool IDs from filesystem
tool_ids=$(find "$TOOLS" -type f -name '*.sh' | xargs -n1 basename | sed 's/\.sh$//' | sort -u)

# Shell workflows
for wf in "$WF_SH"/*.sh; do
    [ -f "$wf" ] || continue
    wf_id="$(basename "$wf" .sh)"
    echo "-- Workflow (shell): $wf_id"

    for tid in $tool_ids; do
        if grep -q "\b$tid\b" "$wf"; then
            echo "   uses: $tid"
        fi
    done
    echo
done

# YAML workflows
while IFS= read -r yaml; do
    [ -f "$yaml" ] || continue
    wf_id="$(basename "$yaml" .yaml)"
    echo "-- Workflow (yaml): $wf_id"

    for tid in $tool_ids; do
        if grep -q "\b$tid\b" "$yaml"; then
            echo "   uses: $tid"
        fi
    done
    echo
done < <(find "$WF_YAML" -type f -name '*.yaml')

echo "=== Call Graph Complete ==="
