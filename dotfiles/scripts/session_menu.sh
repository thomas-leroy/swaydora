#!/usr/bin/env bash
set -euo pipefail

# Build a simple power/session menu and execute selected action.
show_menu() {
  local entries
  entries=$'lock\nlogout\nsuspend\nreboot\npoweroff'
  local menu_launcher="${XDG_CONFIG_HOME:-$HOME/.config}/scripts/menu_launcher.sh"

  if [[ -x "$menu_launcher" ]]; then
    printf '%s\n' "$entries" | "$menu_launcher" --prompt 'Session'
    return 0
  fi

  if command -v wlogout >/dev/null 2>&1; then
    wlogout
    return 1
  fi

  # No launcher available.
  return 1
}

choice="$(show_menu || true)"

case "${choice:-}" in
  lock)
    exec swaylock -f -c 000000
    ;;
  logout)
    exec swaymsg exit
    ;;
  suspend)
    exec systemctl suspend
    ;;
  reboot)
    exec systemctl reboot
    ;;
  poweroff)
    exec systemctl poweroff
    ;;
  *)
    # Ignore empty/cancelled selections.
    exit 0
    ;;
esac
