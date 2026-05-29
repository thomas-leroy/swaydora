#!/usr/bin/env bash
set -euo pipefail

APP_ID='blueman-manager'
WINDOW_CLASS='Blueman-manager'

window_exists() {
  command -v swaymsg >/dev/null 2>&1 || return 1
  if command -v jq >/dev/null 2>&1; then
    swaymsg -t get_tree 2>/dev/null | jq -e --arg app_id "$APP_ID" --arg class "$WINDOW_CLASS" '
      .. | objects | select((.app_id? == $app_id) or (.window_properties.class? == $class))
    ' >/dev/null 2>&1
    return $?
  fi
  swaymsg -t get_tree 2>/dev/null | grep -Eq "\"app_id\":\"$APP_ID\"|\"class\":\"$WINDOW_CLASS\""
}

focus_window() {
  command -v swaymsg >/dev/null 2>&1 || return 1
  swaymsg "[app_id=\"^${APP_ID}$\"] focus" >/dev/null 2>&1 || true
  swaymsg "[class=\"^${WINDOW_CLASS}$\"] focus" >/dev/null 2>&1 || true
}

if window_exists; then
  focus_window
  exit 0
fi

if ! command -v blueman-manager >/dev/null 2>&1; then
  notify-send "Bluetooth" "blueman-manager is not installed" >/dev/null 2>&1 || true
  exit 127
fi

exec blueman-manager
