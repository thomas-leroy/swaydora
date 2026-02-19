#!/usr/bin/env bash
set -euo pipefail

# Reload Sway config.
swaymsg reload

# Restart Waybar cleanly.
if ! command -v waybar >/dev/null 2>&1; then
  notify-send "Dotfiles" "Waybar not found in PATH"
  exit 127
fi

pkill -x waybar || true
WAYBAR_LOG="${XDG_CACHE_HOME:-$HOME/.cache}/waybar.log"
mkdir -p "$(dirname "$WAYBAR_LOG")"
nohup waybar >"$WAYBAR_LOG" 2>&1 &

# Confirm reload to user.
sleep 0.2
if pgrep -x waybar >/dev/null 2>&1; then
  notify-send "Dotfiles" "Sway and Waybar reloaded"
else
  notify-send "Dotfiles" "Waybar failed to start (see $WAYBAR_LOG)"
  exit 1
fi
