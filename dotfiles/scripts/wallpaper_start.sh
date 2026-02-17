#!/usr/bin/env bash
set -euo pipefail

# Default wallpaper path from linked sway config directory.
WALLPAPER="${WALLPAPER:-$HOME/.config/sway/default-wallpaper.svg}"

# Start wallpaper backend depending on available package.
if command -v swww-daemon >/dev/null 2>&1; then
  swww-daemon &
  sleep 0.2
  if [[ -f "$WALLPAPER" ]]; then
    exec swww img "$WALLPAPER" --transition-type simple --transition-duration 0.4
  fi
  wait
fi

# Fallback: keep a solid color background with swaybg.
if command -v swaybg >/dev/null 2>&1; then
  if [[ -f "$WALLPAPER" ]]; then
    exec swaybg -i "$WALLPAPER" -m fill
  fi
  exec swaybg -c '#1d1f21'
fi

# Nothing to start when no wallpaper backend is installed.
exit 0
