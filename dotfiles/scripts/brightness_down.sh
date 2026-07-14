#!/usr/bin/env bash
set -euo pipefail

# Brightness control is optional on desktops, so fail closed with a notification.
if ! command -v brightnessctl >/dev/null 2>&1; then
  notify-send "Brightness" "brightnessctl is not installed"
  exit 1
fi

line="$(brightnessctl -m 2>/dev/null | head -n 1 || true)"
percent_field="$(awk -F',' 'NR==1 {print $4}' <<<"$line")"
percent="${percent_field%\%}"

if [[ ! "$percent" =~ ^[0-9]+$ ]]; then
  notify-send "Brightness" "Current brightness is unavailable"
  exit 1
fi

target=$(( percent - 10 ))
if (( target < 7 )); then
  target=7
fi

brightnessctl set "${target}%"
