#!/usr/bin/env bash
set -euo pipefail

# Read current active keyboard layout name from Sway inputs.
layout_name="$(swaymsg -t get_inputs 2>/dev/null | awk '/"xkb_active_layout_name":/ {gsub(/.*: "/,""); gsub(/".*/,""); print; exit}')"

if [[ -z "$layout_name" ]]; then
  printf '{"text":" ?","class":"warn","tooltip":"Keyboard layout unknown"}\n'
  exit 0
fi

if grep -Eiq 'french|azerty|^fr' <<<"$layout_name"; then
  printf '{"text":" FR","class":"fr","tooltip":"Layout: %s (click to switch)"}\n' "$layout_name"
else
  printf '{"text":" US","class":"us","tooltip":"Layout: %s (click to switch)"}\n' "$layout_name"
fi
