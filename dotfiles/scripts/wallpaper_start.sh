#!/usr/bin/env bash
set -euo pipefail

# Default wallpaper paths from linked sway config directory.
# Override via environment variables to support non-default home layouts.
STATE_FILE="${STATE_FILE:-$HOME/.config/sway/.current_wallpaper}"
DEFAULT_WALLPAPER="${DEFAULT_WALLPAPER:-$HOME/.config/sway/default-wallpaper.svg}"
WALLPAPER="$DEFAULT_WALLPAPER"

# Prefer persisted wallpaper when available.
if [[ -f "$STATE_FILE" ]]; then
  persisted="$(cat "$STATE_FILE" 2>/dev/null || true)"
  if [[ -n "${persisted:-}" && -f "$persisted" ]]; then
    WALLPAPER="$persisted"
  fi
fi

# Start wallpaper backend depending on available package.
if command -v awww >/dev/null 2>&1 && command -v awww-daemon >/dev/null 2>&1; then
  # Avoid racing multiple daemons on Sway reload.
  if ! pgrep -x awww-daemon >/dev/null 2>&1; then
    awww-daemon >/dev/null 2>&1 &
  fi

  # Wait briefly until daemon socket is ready.
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    awww query >/dev/null 2>&1 && break
    sleep 0.1
  done

  if [[ -f "$WALLPAPER" ]]; then
    if awww img "$WALLPAPER" --transition-type left >/dev/null 2>&1; then
      exit 0
    fi
  fi
fi

# Fallback: keep a solid color background with swaybg.
if command -v swaybg >/dev/null 2>&1; then
  pkill -x swaybg >/dev/null 2>&1 || true
  if [[ -f "$WALLPAPER" ]]; then
    exec swaybg -i "$WALLPAPER" -m fill
  fi
  exec swaybg -c '#1d1f21'
fi

# Nothing to start when no wallpaper backend is installed.
if command -v notify-send >/dev/null 2>&1; then
  notify-send "Wallpaper" "awww is not installed"
fi
exit 0
