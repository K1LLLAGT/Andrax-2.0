#!/usr/bin/env bash
# ANDRAX 2.0 — Tool Registry Builder
# Scans termux-backend/tools/*/* and generates tool_registry.json
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="$ROOT/termux-backend/tools"
OUT="$ROOT/android-app/src/main/assets/tool_registry.json"

tmp="$(mktemp)"
echo '{ "categories": [' > "$tmp"

first_category=true

for category_dir in "$TOOLS_DIR"/*; do
    [ -d "$category_dir" ] || continue
    category_id="$(basename "$category_dir")"
    category_name="$(echo "$category_id" | sed 's/_/ /g')"

    # Category comma handling
    if [ "$first_category" = true ]; then
        first_category=false
    else
        echo ',' >> "$tmp"
    fi

    echo "  {" >> "$tmp"
    echo "    \"id\": \"$category_id\"," >> "$tmp"
    echo "    \"name\": \"$category_name\"," >> "$tmp"
    echo "    \"tools\": [" >> "$tmp"

    first_tool=true

    for tool_script in "$category_dir"/*.sh; do
        [ -f "$tool_script" ] || continue

        tool_id="$(basename "$tool_script" .sh)"
        script_rel="termux-backend/tools/$category_id/$tool_id.sh"

        # Extract description from first comment line
        description="$(grep -E '^#' "$tool_script" | head -n 1 | sed 's/^# *//')"
        [ -z "$description" ] && description="No description available."

        # Example usage
        example="andrax run-tool $tool_id -- <args>"

        # Privileged detection
        if grep -q "PRIVILEGED" "$tool_script"; then
            privileged=true
        else
            privileged=false
        fi

        # Tool comma handling
        if [ "$first_tool" = true ]; then
            first_tool=false
        else
            echo ',' >> "$tmp"
        fi

        cat >> "$tmp" <<EOF
      {
        "id": "$tool_id",
        "name": "$tool_id",
        "script": "$script_rel",
        "description": "$description",
        "example": "$example",
        "privileged": $privileged
      }
EOF

    done

    echo "    ]" >> "$tmp"
    echo -n "  }" >> "$tmp"
done

echo '] }' >> "$tmp"

mv "$tmp" "$OUT"

echo "ANDRAX tool registry built:"
echo "  $OUT"
