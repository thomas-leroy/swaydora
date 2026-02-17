#!/usr/bin/env bash
set -euo pipefail

# Validate required tools.
command -v cal >/dev/null 2>&1 || { notify-send "Calendar" "cal command not found"; exit 1; }
command -v fuzzel >/dev/null 2>&1 || { notify-send "Calendar" "fuzzel not found"; exit 1; }

# Show current month calendar in a simple fuzzel popup.
cal | fuzzel --dmenu --prompt 'Calendar' >/dev/null
