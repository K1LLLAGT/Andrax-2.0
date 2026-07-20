#!/usr/bin/env bash

ANDRAX_HOME="$HOME/ANDRAX/ANDRAX-2.0"
TOOL_ID="$1"
shift

TOOL_SCRIPT="$ANDRAX_HOME/termux-backend/tools/$TOOL_ID/$TOOL_ID.sh"

if [ ! -f "$TOOL_SCRIPT" ]; then
    echo "Tool not found: $TOOL_ID"
    exit 1
fi

bash "$TOOL_SCRIPT" "$@"
