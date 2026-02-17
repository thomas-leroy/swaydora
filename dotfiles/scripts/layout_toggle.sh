#!/usr/bin/env bash
set -euo pipefail

# Toggle Sway keyboard layout between FR and US.
layout_name="$(swaymsg -t get_inputs 2>/dev/null | awk '/"xkb_active_layout_name":/ {gsub(/.*: "/,""); gsub(/".*/,""); print; exit}')"

if grep -Eiq 'french|azerty|^fr' <<<"${layout_name:-}"; then
  swaymsg 'input type:keyboard xkb_layout us' >/dev/null
  notify-send "Keyboard layout" "Switched to US"
else
  swaymsg 'input type:keyboard xkb_layout fr' >/dev/null
  notify-send "Keyboard layout" "Switched to FR"
fi
