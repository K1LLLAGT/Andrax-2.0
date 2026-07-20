#!/usr/bin/env bash
# ANDRAX 2.0 — Android Workflow Preview Renderer

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REG_WF="$ROOT/android-app/src/main/assets/workflow_registry.json"

wf_id="${1:-}"
[ -z "$wf_id" ] && { echo "Usage: android_workflow_preview.sh <workflow_id>"; exit 1; }

command -v jq >/dev/null 2>&1 || {
  echo "jq required (pkg install jq)"
  exit 2
}

echo "=== ANDRAX Android Workflow Preview ==="
jq -r '
  .workflows[] | select(.id=="'"$wf_id"'") |
  {
    id,
    name,
    type,
    source,
    description,
    example
  }
' "$REG_WF"
