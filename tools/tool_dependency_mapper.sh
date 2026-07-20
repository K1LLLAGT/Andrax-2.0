#!/usr/bin/env bash
# ANDRAX 2.0 — Tool Dependency Mapper

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS="$ROOT/termux-backend/tools"

echo "=== ANDRAX Tool Dependency Mapper ==="

while IFS= read -r tool; do
    rel="${tool#"$ROOT/"}"
    echo "-- Tool: $rel"

    deps=$(grep -E '\b(nmap|sqlmap|hydra|john|metasploit|msfvenom|dirb|wpscan|binwalk|strings|whois|dnsenum|nikto|mitmproxy|wifi_scan)\b' "$tool" | \
           sed 's/.*\b\(nmap\|sqlmap\|hydra\|john\|metasploit\|msfvenom\|dirb\|wpscan\|binwalk\|strings\|whois\|dnsenum\|nikto\|mitmproxy\|wifi_scan\)\b.*/\1/' | sort -u)

    if [ -z "$deps" ]; then
        echo "  Dependencies: (none detected)"
    else
        echo "  Dependencies:"
        printf '    - %s\n' $deps
    fi
    echo
done < <(find "$TOOLS" -type f -name '*.sh')

echo "=== Mapping Complete ==="
