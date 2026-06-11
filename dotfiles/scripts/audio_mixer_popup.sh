#!/usr/bin/env bash
set -euo pipefail

TITLE='swaydora-audio-mixer'
APP_ID='swaydora-popup'

window_exists() {
  command -v swaymsg >/dev/null 2>&1 || return 1
  if command -v jq >/dev/null 2>&1; then
    swaymsg -t get_tree 2>/dev/null | jq -e --arg title "$TITLE" '.. | objects | select(.name? == $title)' >/dev/null 2>&1
    return $?
  fi
  swaymsg -t get_tree 2>/dev/null | grep -Fq "\"name\":\"$TITLE\""
}

focus_window() {
  command -v swaymsg >/dev/null 2>&1 || return 1
  swaymsg "[title=\"^${TITLE}$\"] focus" >/dev/null 2>&1 || true
}

if window_exists; then
  focus_window
  exit 0
fi

if ! command -v kitty >/dev/null 2>&1; then
  notify-send "Audio Mixer" "kitty not found"
  exit 127
fi

if ! command -v wiremix >/dev/null 2>&1; then
  notify-send "Audio Mixer" "wiremix not found"
  exit 127
fi

exec kitty --title "$TITLE" --class "$APP_ID" --override 'map=escape close_window' wiremix
