#!/usr/bin/env bash
set -euo pipefail

# Return warning JSON when brightnessctl is unavailable.
if ! command -v brightnessctl >/dev/null 2>&1; then
  printf '{"text":"󰃠 ?","class":"warn","tooltip":"brightnessctl not found"}\n'
  exit 0
fi

# Read current and max brightness values.
cur="$(brightnessctl get 2>/dev/null || true)"
max="$(brightnessctl max 2>/dev/null || true)"
if [[ -z "$cur" || -z "$max" || "$max" -le 0 ]]; then
  printf '{"text":"󰃠 ?","class":"warn","tooltip":"No backlight device"}\n'
  exit 0
fi

pct=$(( cur * 100 / max ))

# Emit Waybar JSON with icon and class by level.
if (( pct < 34 )); then
  printf '{"text":"󰃞 %s%%","class":"low","tooltip":"Screen brightness"}\n' "$pct"
elif (( pct < 67 )); then
  printf '{"text":"󰃟 %s%%","class":"medium","tooltip":"Screen brightness"}\n' "$pct"
else
  printf '{"text":"󰃠 %s%%","class":"high","tooltip":"Screen brightness"}\n' "$pct"
fi
