#!/usr/bin/env bash
# ANDRAX 2.0 — Auto‑Documentation Builder
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REG_TOOLS="$ROOT/android-app/src/main/assets/tool_registry.json"
REG_WF="$ROOT/android-app/src/main/assets/workflow_registry.json"
DOC_DIR="$ROOT/docs"

mkdir -p "$DOC_DIR"

TOOLS_MD="$DOC_DIR/TOOLS.md"
WF_MD="$DOC_DIR/WORKFLOWS.md"

command -v jq >/dev/null 2>&1 || {
  echo "jq required (pkg install jq)"
  exit 2
}

# Tools documentation
cat > "$TOOLS_MD" <<'HDR'
# ANDRAX 2.0 — Tool Catalog
HDR

jq -r '
  .categories[] |
  "## " + .name + " (" + .id + ")\n" +
  ( [ .tools[] |
      "- **" + .name + "** (`" + .id + "`)\n" +
      "  - Script: `" + .script + "`\n" +
      "  - Description: " + .description + "\n" +
      "  - Example: `" + .example + "`\n" +
      "  - Privileged: " + (if .privileged then "yes" else "no" end)
    ] | join("\n") )
' "$REG_TOOLS" >> "$TOOLS_MD"

# Workflow documentation
cat > "$WF_MD" <<'HDR'
# ANDRAX 2.0 — Workflow Catalog
HDR

jq -r '
  .workflows[] |
  "## " + .name + " (`" + .id + "`)\n" +
  "- Type: " + .type + "\n" +
  "- Source: `" + .source + "`\n" +
  "- Description: " + .description + "\n" +
  "- Example: `" + .example + "`\n"
' "$REG_WF" >> "$WF_MD"

echo "Docs generated:"
echo "  $TOOLS_MD"
echo "  $WF_MD"
