#!/usr/bin/env bash
set -euo pipefail

# Open graphical power screen when available, fallback to session menu.
if command -v wlogout >/dev/null 2>&1; then
  exec wlogout
fi

exec "$HOME/.config/scripts/session_menu.sh"
