#!/usr/bin/env bash
set -euo pipefail

# Unified dmenu launcher wrapper.
# Priority: wofi (preferred) then fuzzel (fallback).

prompt='Menu'
matching='fuzzy'
insensitive='yes'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt)
      prompt="${2:-$prompt}"
      shift 2
      ;;
    *)
      printf '[menu_launcher] unsupported arg: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

if command -v wofi >/dev/null 2>&1; then
  args=(--dmenu --prompt "$prompt")
  [[ "$matching" == 'fuzzy' ]] && args+=(--matching fuzzy)
  [[ "$insensitive" == 'yes' ]] && args+=(--insensitive)
  exec wofi "${args[@]}"
fi

if command -v fuzzel >/dev/null 2>&1; then
  exec fuzzel --dmenu --prompt "$prompt"
fi

notify-send "Menu" "No launcher found (need wofi or fuzzel)"
exit 127
