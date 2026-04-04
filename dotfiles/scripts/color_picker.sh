#!/usr/bin/env bash
set -euo pipefail

if ! command -v hyprpicker >/dev/null 2>&1; then
  notify-send "Color Picker" "hyprpicker is not installed"
  exit 1
fi

color="$(hyprpicker -a 2>/dev/null || true)"

if [[ -z "${color:-}" ]] && command -v wl-paste >/dev/null 2>&1; then
  color="$(wl-paste -n 2>/dev/null || true)"
fi

if [[ "${color:-}" =~ ^#?[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$ ]]; then
  notify-send "Color Picker" "Copied color: $color"
  exit 0
fi

exit 0
