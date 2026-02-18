#!/usr/bin/env bash
set -euo pipefail

# Validate required tools.
command -v cal >/dev/null 2>&1 || { notify-send "Calendar" "cal command not found"; exit 1; }
MENU_LAUNCHER="${XDG_CONFIG_HOME:-$HOME/.config}/scripts/menu_launcher.sh"
[[ -x "$MENU_LAUNCHER" ]] || { notify-send "Calendar" "menu launcher not found"; exit 1; }

# Show current month calendar in a simple menu popup.
cal | "$MENU_LAUNCHER" --prompt 'Calendar' >/dev/null
