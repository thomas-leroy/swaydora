#!/usr/bin/env bash
set -euo pipefail

# Return warning JSON when brightnessctl is unavailable.
if ! command -v brightnessctl >/dev/null 2>&1; then
  printf '{"text":"󰃞 ?","class":"warn","tooltip":"brightnessctl not found"}\n'
  exit 0
fi

line="$(brightnessctl -m 2>/dev/null | head -n 1 || true)"
if [[ -z "$line" ]]; then
  printf '{"text":"󰃞 ?","class":"warn","tooltip":"No backlight device"}\n'
  exit 0
fi

percent_field="$(awk -F',' 'NR==1 {print $4}' <<<"$line")"
percent="${percent_field%\%}"

if [[ ! "$percent" =~ ^[0-9]+$ ]]; then
  printf '{"text":"󰃞 ?","class":"warn","tooltip":"Brightness unavailable"}\n'
  exit 0
fi

if (( percent < 34 )); then
  printf '{"text":"󰃞 %s%%","class":"low","tooltip":"Screen brightness"}\n' "$percent"
elif (( percent < 67 )); then
  printf '{"text":"󰃟 %s%%","class":"medium","tooltip":"Screen brightness"}\n' "$percent"
else
  printf '{"text":"󰃠 %s%%","class":"high","tooltip":"Screen brightness"}\n' "$percent"
fi
