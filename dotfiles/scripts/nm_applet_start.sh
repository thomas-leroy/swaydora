#!/usr/bin/env bash
set -euo pipefail

# Keep a single healthy tray applet instance across Sway reloads and overlapping autostarts.
command -v nm-applet >/dev/null 2>&1 || exit 0

current_args="$(ps -o args= -u "$UID" -C nm-applet 2>/dev/null | head -n 1 || true)"

if [[ -n "$current_args" ]]; then
  if [[ "$current_args" == "nm-applet --indicator" ]]; then
    exit 0
  fi

  pkill -xu "$UID" nm-applet >/dev/null 2>&1 || true
  sleep 0.2
fi

exec nm-applet --indicator
