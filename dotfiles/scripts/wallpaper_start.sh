#!/usr/bin/env bash
set -euo pipefail

# Default wallpaper paths from linked sway config directory.
STATE_FILE="$HOME/.config/sway/.current_wallpaper"
DEFAULT_WALLPAPER="$HOME/.config/sway/default-wallpaper.svg"
WALLPAPER="$DEFAULT_WALLPAPER"

# Prefer persisted wallpaper when available.
if [[ -f "$STATE_FILE" ]]; then
  persisted="$(cat "$STATE_FILE" 2>/dev/null || true)"
  if [[ -n "${persisted:-}" && -f "$persisted" ]]; then
    WALLPAPER="$persisted"
  fi
fi

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
