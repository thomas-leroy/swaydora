#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -lt 3 ]]; then
  printf 'Usage: %s WORKSPACE APP_ID_REGEX COMMAND...
' "$0" >&2
  exit 64
fi

workspace="$1"
app_id_regex="$2"
shift 2

if ! command -v swaymsg >/dev/null 2>&1; then
  printf 'swaymsg is required
' >&2
  exit 69
fi

"$@" >/dev/null 2>&1 &

for _ in $(seq 1 80); do
  if swaymsg "[app_id="${app_id_regex}"] move container to workspace "${workspace}"" >/dev/null 2>&1; then
    exit 0
  fi
  sleep 0.1
done

exit 0
