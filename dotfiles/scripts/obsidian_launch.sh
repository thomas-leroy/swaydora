#!/usr/bin/env bash
set -euo pipefail

appimage_path="$HOME/.local/opt/obsidian/Obsidian.AppImage"
flatpak_desktop_user="$HOME/.local/share/flatpak/exports/share/applications/md.obsidian.Obsidian.desktop"
flatpak_desktop_system="/var/lib/flatpak/exports/share/applications/md.obsidian.Obsidian.desktop"
export GTK_USE_PORTAL=1

if command -v obsidian >/dev/null 2>&1; then
  exec obsidian --no-sandbox --enable-features=UseOzonePlatform --ozone-platform=wayland
fi

if command -v flatpak >/dev/null 2>&1 && [[ -f "$flatpak_desktop_user" || -f "$flatpak_desktop_system" ]]; then
  exec flatpak run md.obsidian.Obsidian
fi

if [[ -x "$appimage_path" ]]; then
  exec "$appimage_path" --no-sandbox --enable-features=UseOzonePlatform --ozone-platform=wayland
fi

notify-send "Obsidian" "Obsidian is not installed"
exit 1
