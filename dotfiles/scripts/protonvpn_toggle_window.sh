#!/usr/bin/env bash
set -euo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles"
STATE_FILE="$CACHE_DIR/protonvpn_window_state"
mkdir -p "$CACHE_DIR"

launch_protonvpn() {
  if command -v protonvpn-app >/dev/null 2>&1; then
    nohup protonvpn-app >/dev/null 2>&1 &
    return 0
  fi
  if command -v proton-vpn-gtk-app >/dev/null 2>&1; then
    nohup proton-vpn-gtk-app >/dev/null 2>&1 &
    return 0
  fi
  if command -v protonvpn-gui >/dev/null 2>&1; then
    nohup protonvpn-gui >/dev/null 2>&1 &
    return 0
  fi
  if command -v protonvpn >/dev/null 2>&1; then
    nohup protonvpn >/dev/null 2>&1 &
    return 0
  fi
  return 1
}

# Try to target ProtonVPN window via common app_id/class values.
show_cmd='swaymsg "[app_id=\"protonvpn\"] scratchpad show, [app_id=\"ProtonVPN\"] scratchpad show, [class=\"ProtonVPN\"] scratchpad show" >/dev/null 2>&1 || true'
hide_cmd='swaymsg "[app_id=\"protonvpn\"] move scratchpad, [app_id=\"ProtonVPN\"] move scratchpad, [class=\"ProtonVPN\"] move scratchpad" >/dev/null 2>&1 || true'

state='hidden'
if [[ -f "$STATE_FILE" ]]; then
  state="$(cat "$STATE_FILE" 2>/dev/null || printf 'hidden')"
fi

if pgrep -fi 'protonvpn|proton-vpn-gtk-app|protonvpn-app|protonvpn-gui' >/dev/null 2>&1; then
  if [[ "$state" == 'shown' ]]; then
    eval "$hide_cmd"
    printf 'hidden\n' > "$STATE_FILE"
  else
    eval "$show_cmd"
    printf 'shown\n' > "$STATE_FILE"
  fi
  exit 0
fi

# No running app: launch GUI.
if launch_protonvpn; then
  printf 'shown\n' > "$STATE_FILE"
  exit 0
fi

notify-send "Proton VPN" "Proton VPN app not found"
exit 1
