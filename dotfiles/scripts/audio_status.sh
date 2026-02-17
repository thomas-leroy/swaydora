#!/usr/bin/env bash
set -euo pipefail

# Return warning JSON when wpctl is unavailable.
if ! command -v wpctl >/dev/null 2>&1; then
  printf '{"text":" ?","class":"warn","tooltip":"wpctl not found"}\n'
  exit 0
fi

# Read default sink status.
line="$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || true)"
if [[ -z "$line" ]]; then
  printf '{"text":" ?","class":"warn","tooltip":"No default sink"}\n'
  exit 0
fi

# Extract percent volume and mute state.
vol="$(awk '{print int($2 * 100)}' <<<"$line")"
muted='no'
if grep -q 'MUTED' <<<"$line"; then
  muted='yes'
fi

# Emit Waybar JSON.
if [[ "$muted" == 'yes' ]]; then
  printf '{"text":"󰖁 %s%%","class":"warn","tooltip":"Sink muted"}\n' "$vol"
else
  printf '{"text":" %s%%","tooltip":"Default sink volume"}\n' "$vol"
fi
