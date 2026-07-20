#!/usr/bin/env bash
# ANDRAX 2.0 — Android IPC End‑to‑End Test
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IPC="$ROOT/launcher/andrax-ipc-contract.sh"

echo "=== ANDRAX Android IPC End‑to‑End Test ==="

echo "-- Listing workflows via IPC --"
"$IPC" workflow list || echo "IPC list failed"

echo "-- Running recon_basic workflow via IPC --"
"$IPC" workflow recon_basic --test-mode || echo "IPC workflow failed"

echo "=== IPC Test Complete ==="
