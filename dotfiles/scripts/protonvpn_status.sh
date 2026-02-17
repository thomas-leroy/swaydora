#!/usr/bin/env bash
set -euo pipefail

# Return Waybar JSON for Proton VPN connection state.
# Detection priority:
# 1) protonvpn-cli status
# 2) protonvpn status
# 3) nmcli active vpn connection matching "proton"

connected=0
tooltip='Proton VPN: disconnected'

if command -v protonvpn-cli >/dev/null 2>&1; then
  out="$(protonvpn-cli status 2>/dev/null || true)"
  if grep -Eiq 'connected|server:' <<<"$out"; then
    connected=1
    tooltip='Proton VPN: connected'
  fi
elif command -v protonvpn >/dev/null 2>&1; then
  out="$(protonvpn status 2>/dev/null || true)"
  if grep -Eiq 'connected|server:' <<<"$out"; then
    connected=1
    tooltip='Proton VPN: connected'
  fi
elif command -v nmcli >/dev/null 2>&1; then
  out="$(nmcli -t -f NAME,TYPE con show --active 2>/dev/null || true)"
  if grep -Eiq '^.*:vpn$' <<<"$out" && grep -Eiq 'proton' <<<"$out"; then
    connected=1
    tooltip='Proton VPN: connected (NetworkManager)'
  fi
fi

if [[ "$connected" -eq 1 ]]; then
  printf '{"text":"󰌾","class":"on","tooltip":"%s"}\n' "$tooltip"
else
  printf '{"text":"󰌿","class":"off","tooltip":"%s"}\n' "$tooltip"
fi
