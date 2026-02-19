#!/usr/bin/env bash
set -euo pipefail

# Unified dmenu launcher wrapper (wofi).

prompt='Menu'
allow_images='no'
allow_markup='no'
width=''
height=''
sort_order=''

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
    --allow-markup)
      allow_markup='yes'
      shift
      ;;
    --width)
      width="${2:-}"
      shift 2
      ;;
    --height)
      height="${2:-}"
      shift 2
      ;;
    --sort-order)
      sort_order="${2:-}"
      shift 2
      ;;
    *)
      printf '[menu_launcher] unsupported arg: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

if command -v wofi >/dev/null 2>&1; then
  # Prevent stacking multiple wofi menus at once.
  if pgrep -x wofi >/dev/null 2>&1; then
    exit 0
  fi

  args=(--dmenu --prompt "$prompt")
  args+=(--matching fuzzy --insensitive)
  [[ "$allow_images" == 'yes' ]] && args+=(--allow-images)
  [[ "$allow_markup" == 'yes' ]] && args+=(--allow-markup)
  [[ -n "$width" ]] && args+=(--width "$width")
  [[ -n "$height" ]] && args+=(--height "$height")
  [[ -n "$sort_order" ]] && args+=(--sort-order "$sort_order")
  exec wofi "${args[@]}"
fi

notify-send "Menu" "wofi not found"
exit 127
