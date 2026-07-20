#!/usr/bin/env bash
# ANDRAX 2.0 Unified Launcher

# Resolve ANDRAX_HOME portably from this script's location (launcher/ -> root)
# instead of hardcoding an install path. paths.sh also exports the component
# roots used below.
_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$_self_dir/../termux-backend/config/paths.sh"

# Subsystems
SCRIPT_ENGINE="$ANDRAX_ENGINE_DIR/engine.sh"
WORKFLOW_ENGINE="$ANDRAX_HOME/bin/andrax-workflow-run.sh"
TOOL_WRAPPER="$ANDRAX_HOME/bin/andrax-tool-wrapper.sh"

LOG_DIR="$ANDRAX_HOME/launcher/logs"
mkdir -p "$LOG_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_DIR/launcher.log"
}

if [ $# -lt 1 ]; then
    log "ERROR: No command provided."
    exit 1
fi

CMD="$1"
shift

case "$CMD" in
    workflow)
        WF_ID="$1"
        shift
        log "Running workflow: $WF_ID"
        bash "$WORKFLOW_ENGINE" "$WF_ID" "$@" | tee -a "$LOG_DIR/workflow-$WF_ID.log"
        ;;

    tool)
        TOOL_ID="$1"
        shift
        log "Running tool: $TOOL_ID"
        bash "$SCRIPT_ENGINE" run-tool "$TOOL_ID" -- "$@" | tee -a "$LOG_DIR/tool-$TOOL_ID.log"
        ;;

    list-tools)
        bash "$SCRIPT_ENGINE" list-tools
        ;;

    list-workflows)
        bash "$SCRIPT_ENGINE" list-workflows
        ;;

    *)
        log "Unknown command: $CMD"
        exit 1
        ;;
esac
