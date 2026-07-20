#!/usr/bin/env bash
# ANDRAX 2.0 — run a tool by id.
# Resolves the tool through the central launcher (registry id -> script) and
# execs it, passing through all remaining arguments.
# USAGE: run_tool_by_id.sh <tool-id> [-- <tool args...>]
set -euo pipefail

ENGINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ENGINE_DIR/../../termux-backend/config/paths.sh"

[ $# -ge 1 ] || { echo "usage: run-tool <tool-id> -- <args...>"; exit 1; }
tool_id="$1"; shift || true
# Drop a leading "--" separator if present (launch_tool.sh also tolerates it).
[ "${1:-}" = "--" ] && shift || true

exec bash "$ANDRAX_LAUNCHER_DIR/launch_tool.sh" "$tool_id" -- "$@"
