#!/usr/bin/env bash
set -euo pipefail

# Stable Wofi app launcher settings for drun mode.
if ! command -v wofi >/dev/null 2>&1; then
  notify-send "Launcher" "wofi not found"
  exit 127
fi

# Prevent stacked launchers on repeated clicks/shortcuts.
if pgrep -x wofi >/dev/null 2>&1; then
  exit 0
fi

args=(
  --show drun
  --prompt Apps
  --allow-images
  --insensitive
  --matching contains
  --sort-order alphabetical
)

# Hide desktop actions when supported to avoid indented sub-entries.
if wofi --help 2>/dev/null | grep -q -- '--no-actions'; then
  args+=(--no-actions)
fi

exec wofi "${args[@]}"
