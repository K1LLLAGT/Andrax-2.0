#!/usr/bin/env bash
# ANDRAX 2.0 — shared tool-script library.
# Every tool launcher in termux-backend/tools/<category>/*.sh sources this.
#
# It provides:
#   andrax_init            set up logging + traps for one tool invocation
#   andrax_log             timestamped log line (stdout + logfile)
#   andrax_die             log an error and exit non-zero
#   andrax_need            require a binary, or explain how to get it
#   andrax_need_proot      require the proot userland for a tool
#   andrax_run             run a command, tee output to the tool logfile
#   andrax_usage_guard     print $USAGE and exit 0 when no args are given
#   andrax_proot           run a command inside the proot userland
#
# Design: no privileged operations, deterministic logging, honest exit codes.

set -o pipefail

# --- locate config ---------------------------------------------------------
if [ -z "${ANDRAX_HOME:-}" ]; then
    _lib_self="${BASH_SOURCE[0]:-$0}"
    _lib_dir="$(cd "$(dirname "$_lib_self")" && pwd)"
    # lib/ -> tools/ -> termux-backend/ -> ANDRAX-2.0/ ; config is under backend
    . "$_lib_dir/../../config/paths.sh"
fi

# --- state -----------------------------------------------------------------
ANDRAX_TOOL_NAME="${ANDRAX_TOOL_NAME:-tool}"
ANDRAX_TOOL_LOG=""

andrax_init() {
    # $1 = tool name (short id). Sets up the per-run logfile.
    ANDRAX_TOOL_NAME="${1:-$ANDRAX_TOOL_NAME}"
    local ts; ts="$(date +%Y%m%d-%H%M%S)"
    ANDRAX_TOOL_LOG="$ANDRAX_LOG_DIR/${ANDRAX_TOOL_NAME}-${ts}.log"
    mkdir -p "$ANDRAX_LOG_DIR" "$ANDRAX_LOOT_DIR"
    : > "$ANDRAX_TOOL_LOG"
    andrax_log "=== ANDRAX 2.0 :: $ANDRAX_TOOL_NAME :: $(date -Is) ==="
}

andrax_log() {
    # Timestamped line to stdout and (if initialised) the tool logfile.
    local line="[$(date +%H:%M:%S)] $*"
    printf '%s\n' "$line"
    [ -n "$ANDRAX_TOOL_LOG" ] && printf '%s\n' "$line" >> "$ANDRAX_TOOL_LOG"
}

andrax_die() {
    # $*: message. Logs at ERROR and exits 1.
    andrax_log "ERROR: $*"
    exit 1
}

andrax_need() {
    # $1 = binary, $2 = install hint. Dies if missing.
    if ! command -v "$1" >/dev/null 2>&1; then
        andrax_die "'$1' not found. Install it: ${2:-see termux-backend/setup/}"
    fi
}

andrax_need_proot() {
    # Ensure the proot userland exists for tools not packaged in Termux.
    command -v proot-distro >/dev/null 2>&1 \
        || andrax_die "proot-distro missing. Run termux-backend/setup/setup_proot_kali.sh"
    proot-distro list 2>/dev/null | grep -q "$ANDRAX_PROOT_DISTRO" \
        || andrax_die "proot distro '$ANDRAX_PROOT_DISTRO' not installed. Run setup_proot_kali.sh"
}

andrax_proot() {
    # Run a command inside the proot userland. $*: command line.
    andrax_need_proot
    proot-distro login "$ANDRAX_PROOT_DISTRO" -- "$@"
}

andrax_run() {
    # Run a command, echo it, and tee combined output to the tool logfile.
    andrax_log "RUN: $*"
    if [ -n "$ANDRAX_TOOL_LOG" ]; then
        "$@" 2>&1 | tee -a "$ANDRAX_TOOL_LOG"
        return "${PIPESTATUS[0]}"
    else
        "$@"
    fi
}

andrax_usage_guard() {
    # If no args were passed to the tool, print $USAGE and exit 0.
    if [ "$1" -eq 0 ]; then
        printf '%s\n' "${USAGE:-No usage defined for $ANDRAX_TOOL_NAME}"
        exit 0
    fi
}

# A destination path under the loot dir for captured artifacts.
andrax_loot() {
    # $1 = filename. Prints an absolute path inside the run's loot dir.
    local d="$ANDRAX_LOOT_DIR/${ANDRAX_TOOL_NAME}"
    mkdir -p "$d"
    printf '%s/%s-%s\n' "$d" "$(date +%Y%m%d-%H%M%S)" "${1:-out}"
}
