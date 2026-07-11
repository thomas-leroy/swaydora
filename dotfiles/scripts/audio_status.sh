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

# Identify the active Focusrite output from the default sink properties. Keep a
# generic label for built-in, Bluetooth, and unexpectedly named audio devices.
sink_properties="$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null || true)"
sink_label='Output'
sink_name='Output'
sink_class='other-output'
if grep -Eqi 'line[^[:alnum:]]*1[^[:alnum:]]*2' <<<"$sink_properties"; then
  sink_label='󰋎'
  sink_name='Line 1-2'
  sink_class='speakers'
elif grep -Eqi 'line[^[:alnum:]]*3[^[:alnum:]]*4' <<<"$sink_properties"; then
  sink_label='󰓃'
  sink_name='Line 3-4'
  sink_class='headphones'
fi

# Emit Waybar JSON.
if [[ "$muted" == 'yes' ]]; then
  printf '{"text":" %s%% → %s","class":["muted","%s"],"tooltip":"%s · muted"}\n' \
    "$vol" "$sink_label" "$sink_class" "$sink_name"
elif (( vol < 34 )); then
  printf '{"text":" %s%% → %s","class":["low","%s"],"tooltip":"%s · default output"}\n' \
    "$vol" "$sink_label" "$sink_class" "$sink_name"
elif (( vol < 67 )); then
  printf '{"text":" %s%% → %s","class":["medium","%s"],"tooltip":"%s · default output"}\n' \
    "$vol" "$sink_label" "$sink_class" "$sink_name"
else
  printf '{"text":" %s%% → %s","class":["high","%s"],"tooltip":"%s · default output"}\n' \
    "$vol" "$sink_label" "$sink_class" "$sink_name"
fi
