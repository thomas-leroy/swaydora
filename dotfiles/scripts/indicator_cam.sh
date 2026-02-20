#!/usr/bin/env bash
set -euo pipefail

# Hide indicator when no camera device exists.
if ! ls /dev/video* >/dev/null 2>&1; then
  printf '{"text":"","class":"hidden","tooltip":""}\n'
  exit 0
fi

# Detect whether at least one camera device is currently in use.
busy=0
for dev in /dev/video*; do
  if command -v fuser >/dev/null 2>&1 && fuser -s "$dev"; then
    busy=1
    break
  fi
done

# Emit Waybar JSON status.
if [[ "$busy" -eq 1 ]]; then
  printf '{"text":"\uebfa","class":"on","tooltip":"Camera in use"}\n'
else
  printf '{"text":"","class":"hidden","tooltip":""}\n'
fi
