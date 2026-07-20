#!/usr/bin/env bash
# ANDRAX 2.0 — scripting engine (single entrypoint).
# This is the `andrax` command. It ties together the registry, the launcher,
# the workflow engine, environment self-checks, and root availability detection.
#
# USAGE:
#   andrax <command> [args...]
#
# COMMANDS:
#   doctor                         environment self-check (includes root status)
#   doctor --detailed              comprehensive diagnostics + root capabilities
#   doctor --root                  root availability report only
#   list-tools [category]          list tools (optionally by category)
#   list-workflows                 list workflows
#   categories                     list categories
#   run-tool <id> -- <args...>     run a tool by id
#   run-workflow <id> -- <args...> run a workflow by id
#   info <tool-id>                 show tool details from the registry
#   root-check                     detailed root availability & capabilities
#   help                           this message
set -euo pipefail

ENGINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ENGINE_DIR/../termux-backend/config/paths.sh"

# Source root detection utility
if [ -f "$ANDRAX_BACKEND/config/root-detection.sh" ]; then
    . "$ANDRAX_BACKEND/config/root-detection.sh"
else
    # Fallback if root-detection.sh is missing
    _get_root_method() { [ "$(id -u)" -eq 0 ] && echo "direct" || echo "none"; }
    _root_capabilities_check() { echo "⚠️  root-detection.sh not found"; }
    _capability_matrix() { echo "⚠️  root-detection.sh not found"; }
fi

_need_jq() { command -v jq >/dev/null 2>&1 || { echo "andrax: jq required (pkg install jq)"; exit 2; }; }

usage() { sed -n '2,26p' "$ENGINE_DIR/engine.sh" | sed 's/^# \{0,1\}//'; }

cmd="${1:-help}"; shift || true
case "$cmd" in
    help|-h|--help) usage ;;

    doctor)
        echo "ANDRAX 2.0 doctor"
        echo ""
        echo "--- Environment ---"
        echo "  ANDRAX_HOME = $ANDRAX_HOME"
        echo "  registry    = $ANDRAX_REGISTRY $( [ -f "$ANDRAX_REGISTRY" ] && echo OK || echo MISSING )"
        echo "  log dir     = $ANDRAX_LOG_DIR"
        echo "  loot dir    = $ANDRAX_LOOT_DIR"
        echo ""
        
        # Root status
        local root_method="$(_get_root_method)"
        echo "--- Root Access ---"
        case "$root_method" in
            direct)
                echo "  status      = ✅ uid $(id -u) (direct root)"
                ;;
            magisk-module)
                echo "  status      = ✅ Magisk module (andrax-bridge) active"
                ;;
            magisk)
                echo "  status      = ⚠️  Magisk available, module not active"
                ;;
            su)
                echo "  status      = ⚠️  su available (non-optimized)"
                ;;
            none)
                echo "  status      = ❌ no root (connect-scan fallbacks active)"
                ;;
        esac
        
        echo ""
        echo "--- Core Tools ---"
        for t in jq nmap whois dig sqlmap hydra john binwalk strings mitmproxy msfconsole; do
            printf '  %-12s %s\n' "$t" "$(command -v "$t" >/dev/null 2>&1 && echo present || echo '-')"
        done
        
        echo ""
        echo "--- Optional Userland ---"
        echo "  proot distro ($ANDRAX_PROOT_DISTRO):"
        if command -v proot-distro >/dev/null 2>&1 && proot-distro list 2>/dev/null | grep -q "$ANDRAX_PROOT_DISTRO"; then
            echo "    ✅ installed"
        else
            echo "    ❌ not installed (run termux-backend/setup/setup_proot_kali.sh)"
        fi
        
        echo ""
        # Show hint for detailed diagnostics
        echo "💡 For detailed root diagnostics, run: andrax doctor --detailed"
        echo "💡 For root/capabilities only, run: andrax root-check"
        ;;

    doctor)
        # Handle doctor --detailed and doctor --root flags
        if [ $# -gt 0 ]; then
            case "$1" in
                --detailed)
                    echo "ANDRAX 2.0 doctor (detailed)"
                    echo ""
                    echo "--- Environment ---"
                    echo "  ANDRAX_HOME = $ANDRAX_HOME"
                    echo "  registry    = $ANDRAX_REGISTRY $( [ -f "$ANDRAX_REGISTRY" ] && echo OK || echo MISSING )"
                    echo "  log dir     = $ANDRAX_LOG_DIR"
                    echo "  loot dir    = $ANDRAX_LOOT_DIR"
                    echo "  state dir   = $ANDRAX_STATE"
                    echo ""
                    
                    echo "--- Core Tools ---"
                    for t in jq nmap whois dig sqlmap hydra john binwalk strings mitmproxy msfconsole; do
                        printf '  %-12s %s\n' "$t" "$(command -v "$t" >/dev/null 2>&1 && echo present || echo '-')"
                    done
                    
                    echo ""
                    echo "--- Optional Tools ---"
                    for t in proot-distro go rustc python3 npm; do
                        printf '  %-12s %s\n' "$t" "$(command -v "$t" >/dev/null 2>&1 && echo present || echo '-')"
                    done
                    
                    echo ""
                    echo "--- Proot Userland ---"
                    echo "  ANDRAX_PROOT_DISTRO: $ANDRAX_PROOT_DISTRO"
                    if command -v proot-distro >/dev/null 2>&1 && proot-distro list 2>/dev/null | grep -q "$ANDRAX_PROOT_DISTRO"; then
                        echo "  Status: ✅ installed"
                    else
                        echo "  Status: ❌ not installed"
                    fi
                    
                    echo ""
                    _root_capabilities_check
                    _capability_matrix
                    ;;
                --root)
                    _root_capabilities_check
                    _capability_matrix
                    ;;
                *)
                    echo "andrax doctor: unknown flag '$1'" >&2
                    echo "Usage: andrax doctor [--detailed|--root]" >&2
                    exit 1
                    ;;
            esac
        fi
        ;;

    root-check)
        echo ""
        _root_capabilities_check
        _capability_matrix
        echo ""
        ;;

    list-tools)   _need_jq; bash "$ENGINE_DIR/scripts/list_tools.sh" "$@" ;;
    list-workflows) _need_jq; bash "$ENGINE_DIR/scripts/list_workflows.sh" "$@" ;;
    categories)   bash "$ANDRAX_LAUNCHER_DIR/category_dispatch.sh" "$@" ;;

    run-tool)     bash "$ENGINE_DIR/scripts/run_tool_by_id.sh" "$@" ;;
    run-workflow) bash "$ENGINE_DIR/scripts/run_workflow_by_id.sh" "$@" ;;

    info)
        _need_jq
        [ $# -ge 1 ] || { echo "usage: andrax info <tool-id>"; exit 1; }
        jq -r --arg id "$1" '
          .categories[] as $c | $c.tools[] | select(.id==$id) |
          "Tool:        \(.name) (\(.id))",
          "Category:    \($c.name)",
          "Script:      \(.script)",
          "Description: \(.description)",
          "Example:     andrax \(.example)"
        ' "$ANDRAX_REGISTRY" || echo "unknown tool '$1'"
        ;;

    *) echo "andrax: unknown command '$cmd'"; echo; usage; exit 1 ;;
esac
