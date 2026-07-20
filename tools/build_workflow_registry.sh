#!/usr/bin/env bash
# ANDRAX 2.0 — Workflow Registry Builder.
#
# Generates android-app/src/main/assets/workflow_registry.json from the actual
# shell workflows (workflow-engine/workflows/*.sh) and YAML workflows
# (workflows/**/*.yaml). Shell workflows are enriched with the curated name and
# description from the canonical registry (launcher-system/tool_registry.json
# .workflows[]) when an entry exists.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WF_SH_DIR="$ROOT/workflow-engine/workflows"
WF_YAML_DIR="$ROOT/workflows"
CANON="$ROOT/launcher-system/tool_registry.json"
OUT_DIR="$ROOT/android-app/src/main/assets"
OUT="$OUT_DIR/workflow_registry.json"

command -v jq >/dev/null 2>&1 || { echo "jq required (pkg install jq)"; exit 2; }
mkdir -p "$OUT_DIR"

# First comment line that is not the shebang, with the leading "# " stripped.
_header_desc() {
    awk 'NR==1 && /^#!/ { next } /^#/ { sub(/^#[[:space:]]*/, ""); print; exit }' "$1"
}

# Look up a curated field for a workflow id in the canonical registry.
# $1 = id, $2 = field (name|description); prints empty string if absent.
_canon() {
    [ -f "$CANON" ] || { echo ""; return; }
    jq -r --arg id "$1" --arg f "$2" \
        '(.workflows[]? | select(.id==$id) | .[$f]) // empty' "$CANON" 2>/dev/null
}

# JSON-escape a string for embedding in the output.
_json() { printf '%s' "$1" | jq -Rs .; }

tmp="$(mktemp)"
echo '{ "workflows": [' > "$tmp"
first=true

_emit() { # id name type source description
    if [ "$first" = true ]; then first=false; else echo ',' >> "$tmp"; fi
    cat >> "$tmp" <<JSON
  {
    "id": $(_json "$1"),
    "name": $(_json "$2"),
    "type": $(_json "$3"),
    "source": $(_json "$4"),
    "description": $(_json "$5"),
    "example": $(_json "andrax run-workflow $1 -- <args>")
  }
JSON
}

# Shell workflows
if [ -d "$WF_SH_DIR" ]; then
    while IFS= read -r wf; do
        wf_id="$(basename "$wf" .sh)"
        rel="workflow-engine/workflows/$wf_id.sh"
        name="$(_canon "$wf_id" name)"; [ -n "$name" ] || name="$wf_id"
        desc="$(_canon "$wf_id" description)"
        [ -n "$desc" ] || desc="$(_header_desc "$wf")"
        [ -n "$desc" ] || desc="Shell workflow."
        _emit "$wf_id" "$name" "shell" "$rel" "$desc"
    done < <(find "$WF_SH_DIR" -maxdepth 1 -type f -name '*.sh' | sort)
fi

# YAML workflows
if [ -d "$WF_YAML_DIR" ]; then
    while IFS= read -r wf; do
        wf_id="$(basename "$wf" .yaml)"
        rel="${wf#"$ROOT/"}"
        desc="$(_header_desc "$wf")"; [ -n "$desc" ] || desc="YAML workflow."
        _emit "$wf_id" "$wf_id" "yaml" "$rel" "$desc"
    done < <(find "$WF_YAML_DIR" -type f -name '*.yaml' | sort)
fi

echo '] }' >> "$tmp"
jq empty "$tmp" || { echo "generated invalid JSON"; rm -f "$tmp"; exit 5; }
mv "$tmp" "$OUT"

echo "Workflow registry built:"
echo "  $OUT"
