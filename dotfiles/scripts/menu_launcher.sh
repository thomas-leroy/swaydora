#!/usr/bin/env bash
set -euo pipefail

# Unified dmenu launcher wrapper (fuzzel).

prompt='Menu'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt)
      prompt="${2:-$prompt}"
      shift 2
      ;;
    # Silently accepted for caller compatibility; fuzzel handles these via config.
    --allow-images|--allow-markup)
      shift
      ;;
    --width|--height|--sort-order)
      shift 2
      ;;
    *)
      printf '[menu_launcher] unsupported arg: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

if command -v fuzzel >/dev/null 2>&1; then
  if pgrep -x fuzzel >/dev/null 2>&1; then
    exit 0
  fi
  exec fuzzel --dmenu --prompt="${prompt} > "
fi

notify-send "Menu" "fuzzel not found"
exit 127
