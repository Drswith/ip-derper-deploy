#!/bin/bash
set -euo pipefail

shopt -s nullglob

patched=0

for dir in tailscale*/cmd/derper; do
  [ -d "$dir" ] || continue
  for file in "$dir"/*.go; do
    [ -f "$file" ] || continue
    if grep -q 'cert mismatch with hostname' "$file" || grep -q 'cert invalid for hostname' "$file"; then
      cp "$file" "$file.bak"
      sed -i 's/return nil, fmt.Errorf("cert mismatch with hostname: %q", hi.ServerName)/\/\/ disabled: skip domain mismatch check/' "$file"
      sed -i 's/return nil, fmt.Errorf("cert invalid for hostname %q: %w", hostname, err)/\/\/ disabled: skip hostname verification/' "$file"
      patched=1
    fi
  done
done

if [ "$patched" -eq 1 ]; then
  echo "patch applied"
else
  echo "no target files found"
fi
