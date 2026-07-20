#!/usr/bin/env bash
# ANDRAX 2.0 Workflow Runner

ANDRAX_HOME="$HOME/ANDRAX/ANDRAX-2.0"
WF_DIR_YAML="$ANDRAX_HOME/workflows"
WF_DIR_SH="$ANDRAX_HOME/workflow-engine/workflows"

ADAPTER_TERMUX="$ANDRAX_HOME/bin/adapters/adapter-termux.sh"
ADAPTER_MAGISK="$ANDRAX_HOME/bin/adapters/adapter-magisk.sh"

WF_ID="$1"
shift

# Prefer shell workflows first
if [ -f "$WF_DIR_SH/$WF_ID.sh" ]; then
    echo "[Workflow Engine] Running shell workflow: $WF_ID"
    bash "$WF_DIR_SH/$WF_ID.sh" "$@"
    exit 0
fi

# YAML workflow fallback
WF_FILE=$(find "$WF_DIR_YAML" -type f -name "$WF_ID.yaml" | head -n 1)

if [ ! -f "$WF_FILE" ]; then
    echo "Workflow not found: $WF_ID"
    exit 1
fi

echo "[Workflow Engine] Running YAML workflow: $WF_ID"

STEP_NAMES=$(grep -E "name:" "$WF_FILE" | sed 's/name: //')
STEP_CMDS=$(grep -E "run:" "$WF_FILE" | sed 's/run: //')

i=1
while read -r NAME && read -r CMD <&3; do
    echo "Step $i: $NAME"
    echo "Executing: $CMD"

    if echo "$CMD" | grep -q "\[privileged\]"; then
        bash "$ADAPTER_MAGISK" "$CMD"
    else
        bash "$ADAPTER_TERMUX" "$CMD"
    fi

    i=$((i+1))
done <<< "$STEP_NAMES" 3<<< "$STEP_CMDS"
