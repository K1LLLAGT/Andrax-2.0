#!/usr/bin/env bash
# ANDRAX 2.0 — shebang normalizer
# Ensures all .sh files use #!/usr/bin/env bash

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== ANDRAX 2.0 Shebang Normalizer ==="

while IFS= read -r file; do
  first_line="$(head -n 1 "$file" || true)"
  if printf '%s\n' "$first_line" | grep -q '^#!'; then
    # Replace existing shebang
    tail -n +2 "$file" > "$file.tmp"
    printf '%s\n' '#!/usr/bin/env bash' > "$file"
    cat "$file.tmp" >> "$file"
    rm "$file.tmp"
    echo "Normalized: $file"
  else
    # Prepend shebang
    cp "$file" "$file.tmp"
    printf '%s\n' '#!/usr/bin/env bash' > "$file"
    cat "$file.tmp" >> "$file"
    rm "$file.tmp"
    echo "Added shebang: $file"
  fi
done < <(find "$ROOT" -type f -name '*.sh')

echo "=== Done ==="
