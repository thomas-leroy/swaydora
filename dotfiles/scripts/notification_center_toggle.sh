#!/usr/bin/env bash
set -euo pipefail

# Toggle swaync control center panel.
if command -v swaync-client >/dev/null 2>&1; then
  swaync-client -t && exit 0
  swaync-client --toggle-panel && exit 0
fi

notify-send "Notification Center" "swaync-client is not available"
exit 1
