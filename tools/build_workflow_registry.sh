#!/usr/bin/env bash
# ANDRAX 2.0 — Workflow Registry Builder (Corrected)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WF_SH_DIR="$ROOT/workflow-engine/workflows"
WF_YAML_DIR="$ROOT/workflows"
OUT_DIR="$ROOT/android-app/src/main/assets"
OUT="$OUT_DIR/workflow_registry.json"

mkdir -p "$OUT_DIR"

tmp="$(mktemp)"
echo '{ "workflows": [' > "$tmp"

first=true

# Shell workflows
for wf in "$WF_SH_DIR"/*.sh; do
    [ -f "$wf" ] || continue
    wf_id="$(basename "$wf" .sh)"
    rel="workflow-engine/workflows/$wf_id.sh"
    desc="$(grep -E '^#' "$wf" | head -n 1 | sed 's/^# *//')"
    [ -z "$desc" ] && desc="Shell workflow."

    if [ "$first" = true ]; then first=false; else echo ',' >> "$tmp"; fi

    cat >> "$tmp" <<JSON
  {
    "id": "$wf_id",
    "name": "$wf_id",
    "type": "shell",
    "source": "$rel",
    "description": "$desc",
    "example": "andrax run-workflow $wf_id -- <args>"
  }
JSON
done

# YAML workflows
while IFS= read -r wf; do
    [ -f "$wf" ] || continue
    wf_id="$(basename "$wf" .yaml)"
    rel="${wf#"$ROOT/"}"
    desc="$(grep -E '^#' "$wf" | head -n 1 | sed 's/^# *//')"
    [ -z "$desc" ] && desc="YAML workflow."

    if [ "$first" = true ]; then first=false; else echo ',' >> "$tmp"; fi

    cat >> "$tmp" <<JSON
  {
    "id": "$wf_id",
    "name": "$wf_id",
    "type": "yaml",
    "source": "$rel",
    "description": "$desc",
    "example": "andrax run-workflow $wf_id -- <args>"
  }
JSON
done < <(find "$WF_YAML_DIR" -type f -name '*.yaml')

echo '] }' >> "$tmp"
mv "$tmp" "$OUT"

echo "Workflow registry built:"
echo "  $OUT"
