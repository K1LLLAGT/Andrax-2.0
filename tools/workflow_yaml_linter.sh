#!/usr/bin/env bash
# ANDRAX 2.0 — Workflow YAML Linter
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WF_DIR="$ROOT/workflows"

echo "=== ANDRAX Workflow YAML Linter ==="

command -v yq >/dev/null 2>&1 || {
  echo "yq required (pkg install yq)"
  exit 2
}

while IFS= read -r yaml; do
  echo "-- Checking: $yaml"

  # Syntax check
  if yq e '.' "$yaml" >/dev/null 2>&1; then
    echo "  Syntax: OK"
  else
    echo "  Syntax: ERROR"
    yq e '.' "$yaml" 2>&1 | sed 's/^/    /'
    continue
  fi

  # Required fields
  for field in id name steps; do
    if yq e ".$field" "$yaml" >/dev/null 2>&1; then
      echo "  Field '$field': OK"
    else
      echo "  Field '$field': MISSING"
    fi
  done

  echo
done < <(find "$WF_DIR" -type f -name '*.yaml')

echo "=== YAML Lint Complete ==="
