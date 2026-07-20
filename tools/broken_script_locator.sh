#!/usr/bin/env bash
# ANDRAX 2.0 — broken-script locator
# Runs bash -n on every .sh and reports syntax errors.

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== ANDRAX 2.0 Broken Script Locator ==="

errors=0

while IFS= read -r file; do
  if bash -n "$file" 2>/dev/null; then
    continue
  else
    echo "SYNTAX ERROR: $file"
    bash -n "$file" 2>&1 | sed 's/^/  /'
    errors=$((errors+1))
  fi
done < <(find "$ROOT" -type f -name '*.sh')

echo
echo "Total broken scripts: $errors"
echo "=== Done ==="
