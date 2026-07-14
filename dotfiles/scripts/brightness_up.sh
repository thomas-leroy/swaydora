#!/usr/bin/env bash
set -euo pipefail

# Brightness control is optional on desktops, so fail closed with a notification.
if ! command -v brightnessctl >/dev/null 2>&1; then
  notify-send "Brightness" "brightnessctl is not installed"
  exit 1
fi

brightnessctl set 10%+
