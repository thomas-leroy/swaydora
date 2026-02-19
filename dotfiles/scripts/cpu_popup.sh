#!/usr/bin/env bash
set -euo pipefail

TITLE='Tools TUI: CPU'

window_exists() {
  command -v swaymsg >/dev/null 2>&1 || return 1
  if command -v jq >/dev/null 2>&1; then
    swaymsg -t get_tree 2>/dev/null | jq -e --arg t "$TITLE" '.. | objects | select(.name? == $t)' >/dev/null 2>&1
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
  notify-send "CPU Monitor" "kitty not found"
  exit 127
fi

exec kitty --title "$TITLE" sh -lc 'if command -v btop >/dev/null 2>&1; then exec btop; fi; echo "btop not found."; echo; read -r -p "Press Enter to close..." _'
