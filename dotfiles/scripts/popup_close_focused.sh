#!/usr/bin/env bash
set -euo pipefail

POPUP_APP_ID='swaydora-popup'
POPUP_TITLE_PREFIX='swaydora-'

command -v swaymsg >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

focused="$(
  swaymsg -t get_tree 2>/dev/null | jq -er '
    .. | objects
    | select(.focused? == true)
    | [.id, (.app_id // ""), (.name // "")]
    | @tsv
  ' 2>/dev/null || true
)"

[[ -n "$focused" ]] || exit 0

IFS=$'\t' read -r con_id app_id title <<<"$focused"

if [[ "$app_id" != "$POPUP_APP_ID" ]]; then
  exit 0
fi

case "$title" in
  "${POPUP_TITLE_PREFIX}"*)
    swaymsg "[con_id=${con_id}] kill" >/dev/null 2>&1 || true
    ;;
esac
