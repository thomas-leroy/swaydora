#!/usr/bin/env bash
set -euo pipefail

if command -v firefox >/dev/null 2>&1; then
  exec firefox
fi

if command -v chromium >/dev/null 2>&1; then
  exec chromium
fi

if command -v google-chrome-stable >/dev/null 2>&1; then
  exec google-chrome-stable
fi

if command -v google-chrome >/dev/null 2>&1; then
  exec google-chrome
fi

if command -v brave-browser >/dev/null 2>&1; then
  exec brave-browser
fi

if command -v vivaldi >/dev/null 2>&1; then
  exec vivaldi
fi

notify-send "Browser" "No supported browser found (firefox/chromium/chrome/brave/vivaldi)"
exit 127
