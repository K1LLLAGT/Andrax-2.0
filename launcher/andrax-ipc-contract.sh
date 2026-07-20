#!/usr/bin/env bash
# ANDRAX 2.0 — IPC contract shim
# Expected CLI from Android app:
#   andrax-ipc-contract.sh workflow <id> [args...]
#   andrax-ipc-contract.sh tool <id> [args...]

set -euo pipefail

# Resolve paths portably from this script's location instead of hardcoding.
_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$_self_dir/../termux-backend/config/paths.sh"
LAUNCHER="$ANDRAX_HOME/launcher/andrax-launcher.sh"

cmd="${1:-}"; shift || true

case "$cmd" in
  workflow)
    wf_id="${1:-}"; shift || true
    exec bash "$LAUNCHER" workflow "$wf_id" "$@"
    ;;
  tool)
    tool_id="${1:-}"; shift || true
    exec bash "$LAUNCHER" tool "$tool_id" "$@"
    ;;
  *)
    echo "IPC: unknown command '$cmd'"
    exit 1
    ;;
esac
