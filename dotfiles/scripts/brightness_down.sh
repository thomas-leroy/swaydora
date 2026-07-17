#!/usr/bin/env bash
set -euo pipefail

if ! command -v brightnessctl >/dev/null 2>&1; then
  notify-send "Brightness" "brightnessctl is not installed"
  exit 1
fi

line="$(brightnessctl --class=backlight -m 2>/dev/null | head -n 1 || true)"
percent_field="$(awk -F',' 'NR==1 {print $4}' <<<"$line")"
percent="${percent_field%\%}"

if [[ ! "$percent" =~ ^[0-9]+$ ]]; then
  exit 0
fi

target=$(( percent - 10 ))
if (( target < 7 )); then
  target=7
fi

brightnessctl --class=backlight set "${target}%"
