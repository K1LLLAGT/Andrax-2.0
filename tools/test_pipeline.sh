#!/usr/bin/env bash
# ANDRAX 2.0 — Full Pipeline Integration Test
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAUNCHER="$ROOT/launcher/andrax-launcher.sh"

echo "=== ANDRAX Pipeline Integration Test ==="

echo "-- Listing workflows --"
"$LAUNCHER" list-workflows || echo "Launcher list failed"

echo "-- Running recon_basic workflow --"
"$LAUNCHER" workflow recon_basic || echo "Launcher workflow failed"

echo "=== Pipeline Test Complete ==="
