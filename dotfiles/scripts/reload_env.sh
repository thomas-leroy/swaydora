#!/usr/bin/env bash
set -euo pipefail

# Reload Sway config.
swaymsg reload

# Restart Waybar cleanly.
pkill -x waybar || true
nohup waybar >/dev/null 2>&1 &

# Confirm reload to user.
notify-send "Dotfiles" "Sway and Waybar reloaded"
