#!/usr/bin/env bash
set -euo pipefail

APPIMAGE_PATH="${HOME}/.local/opt/localsend/LocalSend.AppImage"

if command -v localsend >/dev/null 2>&1; then
  exec localsend
fi

if command -v localsend_app >/dev/null 2>&1; then
  exec localsend_app
fi

if [[ -x "$APPIMAGE_PATH" ]]; then
  exec "$APPIMAGE_PATH"
fi

if command -v gtk-launch >/dev/null 2>&1; then
  exec gtk-launch org.localsend.localsend_app
fi

notify-send "LocalSend" "LocalSend n'est pas installe"
exit 127
