#!/usr/bin/env bash
# ANDRAX 2.0 — root availability detection utility.
# Sourced by the doctor command and tool scripts to check for root capability,
# Magisk availability, and provide diagnostic info.
#
# FUNCTIONS:
#   _check_root_uid          Check if running as uid 0
#   _check_magisk_available  Check if Magisk is installed
#   _check_magisk_module     Check if andrax-bridge module is active
#   _check_su_available      Check if `su` command is available
#   _get_root_method         Determine how root is available (direct/magisk/none)
#   _root_capabilities_check Get detailed root capability report
#   _capability_matrix       Show feature availability matrix

set -euo pipefail

# === Root Detection Functions ===

# Check if the current process has uid 0 (direct root)
_check_root_uid() {
    [ "$(id -u)" -eq 0 ] && echo "true" || echo "false"
}

# Check if Magisk is installed by looking for Magisk manager binary
_check_magisk_available() {
    if command -v magisk >/dev/null 2>&1; then
        echo "true"
    elif [ -f "/data/adb/magisk/magisk" ]; then
        echo "true"
    else
        echo "false"
    fi
}

# Check if the andrax-bridge Magisk module is active
_check_magisk_module() {
    local module_id="andrax-bridge"
    
    # Check if module exists and is enabled in Magisk
    if [ -d "/data/adb/modules/$module_id" ]; then
        # If the module has a disable marker, it's not active
        if [ ! -f "/data/adb/modules/$module_id/disable" ]; then
            echo "true"
        else
            echo "false"
        fi
    else
        echo "false"
    fi
}

# Check if `su` command is available (indicates some form of root access)
_check_su_available() {
    if command -v su >/dev/null 2>&1; then
        echo "true"
    else
        echo "false"
    fi
}

# Determine the root method available (direct/magisk/su/none)
_get_root_method() {
    if [ "$(_check_root_uid)" = "true" ]; then
        echo "direct"
    elif [ "$(_check_magisk_module)" = "true" ]; then
        echo "magisk-module"
    elif [ "$(_check_magisk_available)" = "true" ] && [ "$(_check_su_available)" = "true" ]; then
        echo "magisk"
    elif [ "$(_check_su_available)" = "true" ]; then
        echo "su"
    else
        echo "none"
    fi
}

# Get a detailed root capabilities report
_root_capabilities_check() {
    local root_method="$(_get_root_method)"
    local has_root_uid="$(_check_root_uid)"
    local has_magisk="$(_check_magisk_available)"
    local has_module="$(_check_magisk_module)"
    local has_su="$(_check_su_available)"
    
    echo "=== Root Availability Report ==="
    echo ""
    echo "Current UID: $(id -u)"
    echo "Running as root: $has_root_uid"
    echo ""
    echo "--- Magisk Status ---"
    echo "Magisk installed: $has_magisk"
    echo "andrax-bridge module active: $has_module"
    echo ""
    echo "--- Alternative Root Access ---"
    echo "su command available: $has_su"
    echo ""
    echo "--- Root Method ---"
    echo "Detected method: $root_method"
    echo ""
    
    # Print capabilities based on root method
    case "$root_method" in
        direct)
            echo "✅ Full root access (direct uid 0)"
            echo "   • Raw socket operations enabled"
            echo "   • SYN scans, packet injection, monitor mode available"
            ;;
        magisk-module)
            echo "✅ Root via Magisk module (andrax-bridge)"
            echo "   • Enhanced capabilities available"
            echo "   • Module is actively binding privileged binaries"
            ;;
        magisk)
            echo "⚠️  Magisk installed, andrax-bridge module not active"
            echo "   • Install/enable the andrax-bridge Magisk module for enhanced features"
            echo "   • Run: cd magisk-module && bash install.sh"
            ;;
        su)
            echo "⚠️  su command available, but Magisk not detected"
            echo "   • Some root features may work, but not optimized"
            echo "   • Consider installing Magisk + andrax-bridge module"
            ;;
        none)
            echo "❌ No root access available"
            echo "   • Running in non-root mode (normal for modern Android)"
            echo "   • Core ANDRAX 2.0 functionality available (connect scans, DNS, web scanning)"
            echo "   • Advanced features (SYN scans, raw sockets) unavailable"
            ;;
    esac
}

# === Capability Matrix ===

# Check which capabilities are available given current root status
_capability_matrix() {
    local root_method="$(_get_root_method)"
    
    echo ""
    echo "=== Tool Capability Matrix ==="
    echo ""
    echo "                                      | Non-root | With Root"
    echo "----------------------------------------------|----------|----------"
    echo "TCP/UDP scanning (nmap -sT)          |    ✅    |    ✅"
    echo "SYN scans (nmap -sS)                 |    ❌    |    ✅"
    echo "UDP scans (nmap -sU)                 |    ✅    |    ✅"
    echo "Service detection (-sV)              |    ✅    |    ✅"
    echo "OS fingerprinting                    |    ❌    |    ✅"
    echo "Raw packet injection                 |    ❌    |    ✅"
    echo "Wi-Fi monitor mode                   |    ❌    |    ❌ (hardware)"
    echo "Wi-Fi packet capture                 |    ❌    |    ❌ (hardware)"
    echo "ARP spoofing                         |    ❌    |    ✅"
    echo "MITM proxy (transparent)             |    ❌    |    ✅"
    echo "Metasploit Framework                 |    ✅    |    ✅"
    echo "SQL injection testing                |    ✅    |    ✅"
    echo "Credential brute forcing             |    ✅    |    ✅"
    echo "DNS enumeration                      |    ✅    |    ✅"
    echo "Web scanning                         |    ✅    |    ✅"
    echo ""
    
    if [ "$root_method" = "none" ]; then
        echo "📌 Current Status: Non-root mode"
        echo "   Most web/application security testing is available."
        echo "   Network-level features (SYN scans, ARP spoofing) are unavailable."
    else
        echo "📌 Current Status: Root access available ($root_method)"
        echo "   All network-level features are available."
    fi
}

# Export functions
export -f _check_root_uid
export -f _check_magisk_available
export -f _check_magisk_module
export -f _check_su_available
export -f _get_root_method
export -f _root_capabilities_check
export -f _capability_matrix
