#!/usr/bin/env bash
set -euo pipefail

# Start wallpaper backend depending on available package.
if command -v swww-daemon >/dev/null 2>&1; then
  exec swww-daemon
fi

# Fallback: keep a solid color background with swaybg.
if command -v swaybg >/dev/null 2>&1; then
  exec swaybg -c '#1d1f21'
fi

# Nothing to start when no wallpaper backend is installed.
exit 0
