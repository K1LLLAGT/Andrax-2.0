#!/usr/bin/env bash
# ANDRAX 2.0 Workflow Runner

# Resolve ANDRAX_HOME portably from this script's location (bin/ -> root)
# instead of hardcoding an install path.
_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$_self_dir/../termux-backend/config/paths.sh"

WF_DIR_YAML="$ANDRAX_HOME/workflows"
WF_DIR_SH="$ANDRAX_HOME/workflow-engine/workflows"

ADAPTER_TERMUX="$ANDRAX_HOME/bin/adapters/adapter-termux.sh"
ADAPTER_MAGISK="$ANDRAX_HOME/bin/adapters/adapter-magisk.sh"

WF_ID="$1"
shift || true

# Prefer shell workflows first
if [ -f "$WF_DIR_SH/$WF_ID.sh" ]; then
    echo "[Workflow Engine] Running shell workflow: $WF_ID"
    bash "$WF_DIR_SH/$WF_ID.sh" "$@"
    exit $?
fi

# YAML workflow fallback
WF_FILE=$(find "$WF_DIR_YAML" -type f -name "$WF_ID.yaml" | head -n 1)

if [ ! -f "$WF_FILE" ]; then
    echo "Workflow not found: $WF_ID"
    exit 1
fi

echo "[Workflow Engine] Running YAML workflow: $WF_ID"

# The first remaining argument is the {{target}} placeholder value.
TARGET="${1:-}"

STEP_NAMES=$(grep -E "name:" "$WF_FILE" | sed 's/.*name: *//')
STEP_CMDS=$(grep -E "run:" "$WF_FILE" | sed 's/.*run: *//')

i=1
while read -r NAME && read -r CMD <&3; do
    # Strip surrounding quotes left over from the YAML value.
    CMD="${CMD%\"}"; CMD="${CMD#\"}"

    # Detect + strip the [privileged] marker.
    privileged=false
    if printf '%s' "$CMD" | grep -q "\[privileged\]"; then
        privileged=true
        CMD="$(printf '%s' "$CMD" | sed 's/\[privileged\]//g')"
    fi

    # Substitute {{target}} with the caller-supplied target.
    CMD="${CMD//\{\{target\}\}/$TARGET}"
    # Trim leading/trailing whitespace.
    CMD="$(printf '%s' "$CMD" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

    echo "Step $i: $NAME"
    echo "Executing: $CMD"

    if [ "$privileged" = true ]; then
        bash "$ADAPTER_MAGISK" "$CMD"
    else
        bash "$ADAPTER_TERMUX" "$CMD"
    fi

    i=$((i+1))
done <<< "$STEP_NAMES" 3<<< "$STEP_CMDS"
