#!/usr/bin/env bash
# ANDRAX 2.0 — privileged-tool detector
# Finds scripts marked as PRIVILEGED or clearly needing root.

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== ANDRAX 2.0 Privileged Tool Detector ==="

while IFS= read -r file; do
  if grep -q 'PRIVILEGED' "$file"; then
    echo "PRIVILEGED TAG: $file"
    continue
  fi
  if grep -Eq '\bsu\b|\biptables\b|\btcpdump\b|\bnmap\b' "$file"; then
    echo "LIKELY PRIVILEGED: $file"
  fi
done < <(find "$ROOT" -type f -name '*.sh')

echo "=== Done ==="
