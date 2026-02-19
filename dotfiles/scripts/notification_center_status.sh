#!/usr/bin/env bash
set -euo pipefail

# Icons requested for Waybar.
ICON_NOTIF_ON='\uf0f3'
ICON_NOTIF_OFF='\udb82\ude91'

# Return degraded state when swaync-client is not installed.
if ! command -v swaync-client >/dev/null 2>&1; then
  printf '{"text":"%s ?","class":"warn","tooltip":"swaync-client not found"}\n' "$ICON_NOTIF_ON"
  exit 0
fi

# Try to read Do-Not-Disturb state using non-mutating commands only.
dnd_raw=""
for cmd in \
  "swaync-client --get-dnd" \
  "swaync-client -D" \
  "swaync-client --dnd-state"
do
  candidate="$(eval "$cmd" 2>/dev/null || true)"
  if [[ -n "$candidate" ]]; then
    dnd_raw="$candidate"
    break
  fi
done

dnd_state="$(printf '%s' "$dnd_raw" | tr '[:upper:]' '[:lower:]')"
dnd_enabled=false
if printf '%s' "$dnd_state" | grep -Eq '("dnd"[[:space:]]*:[[:space:]]*true)|(^|[^a-z])(true|1|on|enabled|yes)([^a-z]|$)'; then
  dnd_enabled=true
fi

# Show icon based on availability + DND state.
if pgrep -x swaync >/dev/null 2>&1; then
  if [[ "$dnd_enabled" == true ]]; then
    printf '{"text":"%s","class":"warn","tooltip":"Notifications disabled (DND)"}\n' "$ICON_NOTIF_OFF"
  else
    printf '{"text":"%s","tooltip":"Notification Center (click to toggle)"}\n' "$ICON_NOTIF_ON"
  fi
else
  printf '{"text":"%s","class":"warn","tooltip":"swaync is not running"}\n' "$ICON_NOTIF_ON"
fi
