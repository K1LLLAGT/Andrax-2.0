#!/usr/bin/env bash
# ANDRAX 2.0 — Tool Registry Sync + Validator
#
# The canonical tool registry is the hand-authored, richer
# launcher-system/tool_registry.json (this is ANDRAX_REGISTRY, what the engine,
# launcher, and workflows actually read). The Android app reads a byte-for-byte
# copy at android-app/src/main/assets/tool_registry.json.
#
# This script keeps the app asset in sync with the canonical registry and
# validates that every tool script on disk is registered (and every registered
# script exists). It deliberately does NOT regenerate the registry from the
# filesystem: display names, icons, curated descriptions, examples, and the
# workflow list cannot be derived from the scripts and would be lost.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CANON="$ROOT/launcher-system/tool_registry.json"
TOOLS_DIR="$ROOT/termux-backend/tools"
OUT="$ROOT/android-app/src/main/assets/tool_registry.json"

command -v jq >/dev/null 2>&1 || { echo "jq required (pkg install jq)"; exit 2; }
[ -f "$CANON" ] || { echo "canonical registry missing: $CANON"; exit 3; }
jq empty "$CANON" 2>/dev/null || { echo "canonical registry is not valid JSON: $CANON"; exit 4; }

status=0

# 1. Every tool script on disk (excluding the shared lib/) must be registered.
while IFS= read -r script; do
    rel="${script#"$TOOLS_DIR/"}"                 # e.g. info_gathering/nmap.sh
    if ! jq -e --arg s "$rel" \
        '[.categories[].tools[].script] | index($s)' "$CANON" >/dev/null; then
        echo "WARN: tool script not in registry: $rel"
        status=1
    fi
done < <(find "$TOOLS_DIR" -type f -name '*.sh' -not -path "$TOOLS_DIR/lib/*" | sort)

# 2. Every registered script must exist on disk.
while IFS= read -r rel; do
    [ -f "$TOOLS_DIR/$rel" ] || { echo "WARN: registered script missing on disk: $rel"; status=1; }
done < <(jq -r '.categories[].tools[].script' "$CANON")

# 3. Sync the app asset from the canonical registry.
mkdir -p "$(dirname "$OUT")"
cp "$CANON" "$OUT"

echo "ANDRAX tool registry synced:"
echo "  canonical -> $CANON"
echo "  app asset -> $OUT"
[ "$status" -eq 0 ] && echo "  validation: OK" || echo "  validation: WARNINGS (see above)"
exit "$status"
