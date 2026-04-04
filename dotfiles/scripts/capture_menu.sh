#!/usr/bin/env bash
set -euo pipefail

MENU_LAUNCHER="${XDG_CONFIG_HOME:-$HOME/.config}/scripts/menu_launcher.sh"

[[ -x "$MENU_LAUNCHER" ]] || {
  notify-send "Capture" "menu launcher not found"
  exit 1
}

choice="$(
  printf '%s\n' \
    'Screenshot' \
    'Active window' \
    'Color picker' | "$MENU_LAUNCHER" --prompt 'Capture'
)"

case "${choice:-}" in
  Screenshot)
    exec "${XDG_CONFIG_HOME:-$HOME/.config}/scripts/screenshot_capture.sh"
    ;;
  "Active window")
    exec "${XDG_CONFIG_HOME:-$HOME/.config}/scripts/screenshot_active_window.sh"
    ;;
  "Color picker")
    exec "${XDG_CONFIG_HOME:-$HOME/.config}/scripts/color_picker.sh"
    ;;
  *)
    exit 0
    ;;
esac
