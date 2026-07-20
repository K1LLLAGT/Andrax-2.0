#!/usr/bin/env bash
# ANDRAX 2.0 — tool wrapper.
# Thin shim that resolves a tool by registry id through the central launcher.
# USAGE: andrax-tool-wrapper.sh <tool-id> [-- <tool args...>]

_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$_self_dir/../termux-backend/config/paths.sh"

TOOL_ID="${1:-}"; shift || true
[ "${1:-}" = "--" ] && shift || true

[ -n "$TOOL_ID" ] || { echo "usage: andrax-tool-wrapper.sh <tool-id> [-- <args...>]"; exit 1; }

exec bash "$ANDRAX_LAUNCHER_DIR/launch_tool.sh" "$TOOL_ID" -- "$@"
