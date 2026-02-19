#!/usr/bin/env bash
set -euo pipefail

# Unified dmenu launcher wrapper (wofi).

prompt='Menu'
allow_images='no'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt)
      prompt="${2:-$prompt}"
      shift 2
      ;;
    --allow-images)
      allow_images='yes'
      shift
      ;;
    *)
      printf '[menu_launcher] unsupported arg: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

if command -v wofi >/dev/null 2>&1; then
  args=(--dmenu --prompt "$prompt")
  args+=(--matching fuzzy --insensitive)
  [[ "$allow_images" == 'yes' ]] && args+=(--allow-images)
  exec wofi "${args[@]}"
fi

notify-send "Menu" "wofi not found"
exit 127
