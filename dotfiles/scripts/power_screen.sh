#!/usr/bin/env bash
set -euo pipefail

# Open graphical power screen when available, fallback to session menu.
if command -v wlogout >/dev/null 2>&1; then
  # Toggle behavior: if already open, close it.
  if pgrep -x wlogout >/dev/null 2>&1; then
    pkill -x wlogout
    exit 0
  fi

  # Prefer explicit config paths, then fallback to default invocation.
  if wlogout --layout "$HOME/.config/wlogout/layout" --css "$HOME/.config/wlogout/style.css"; then
    exit 0
  fi

  if wlogout; then
    exit 0
  fi
fi

exec "$HOME/.config/scripts/session_menu.sh"
