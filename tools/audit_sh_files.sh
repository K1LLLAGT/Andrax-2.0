#!/usr/bin/env bash
# ANDRAX 2.0 — Shell Script Auditor
# Scans all .sh files, prints paths, checks syntax, shebang, permissions, size, privileged flag.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== ANDRAX 2.0 Shell Script Audit ==="
echo "Root: $ROOT"
echo

while IFS= read -r file; do
    echo "FILE: $file"

    # Basic metadata
    size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file")
    echo "  Size: $size bytes"

    # Shebang check
    if head -n 1 "$file" | grep -q '^#!'; then
        echo "  Shebang: OK"
    else
        echo "  Shebang: MISSING"
    fi

    # Executable check
    if [ -x "$file" ]; then
        echo "  Executable: yes"
    else
        echo "  Executable: no"
    fi

    # Syntax check
    if bash -n "$file" 2>/dev/null; then
        echo "  Syntax: OK"
    else
        echo "  Syntax: ERROR"
    fi

    # Privileged flag detection
    if grep -q "PRIVILEGED" "$file"; then
        echo "  Privileged: yes"
    else
        echo "  Privileged: no"
    fi

    echo
done < <(find "$ROOT" -type f -name '*.sh' | sort)

echo "=== Audit Complete ==="
