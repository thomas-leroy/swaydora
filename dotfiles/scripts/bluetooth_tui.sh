#!/usr/bin/env bash
set -euo pipefail

TITLE='Tools TUI: Bluetooth'
BLUETUITH_BIN="$HOME/.local/opt/bluetuith/bluetuith"

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
  notify-send "Bluetooth" "kitty not found"
  exit 127
fi

exec kitty --title "$TITLE" sh -lc "
  export PATH=\"\$HOME/.local/bin:\$PATH\"
  cmd=''
  if command -v bluetuith >/dev/null 2>&1; then
    cmd='bluetuith'
  elif [[ -x \"$BLUETUITH_BIN\" ]]; then
    cmd=\"$BLUETUITH_BIN\"
  elif command -v bluetui >/dev/null 2>&1; then
    cmd='bluetui'
  fi

  if [[ -z \"\$cmd\" ]]; then
    echo 'bluetuith/bluetui not found.'
    echo
    read -r -p 'Press Enter to close...' _
    exit 127
  fi

  \"\$cmd\"
  status=\$?
  echo
  echo \"Bluetooth TUI exited with status \$status.\"
  read -r -p 'Press Enter to close...' _
"
