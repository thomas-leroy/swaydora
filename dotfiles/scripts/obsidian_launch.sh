#!/usr/bin/env bash
set -euo pipefail

appimage_path="$HOME/.local/opt/obsidian/Obsidian.AppImage"
export GTK_USE_PORTAL=1

if command -v obsidian >/dev/null 2>&1; then
  exec obsidian --no-sandbox --enable-features=UseOzonePlatform --ozone-platform=wayland
fi

if [[ -x "$appimage_path" ]]; then
  exec "$appimage_path" --no-sandbox --enable-features=UseOzonePlatform --ozone-platform=wayland
fi

notify-send "Obsidian" "Obsidian is not installed"
exit 1
