#!/usr/bin/env bash
set -euo pipefail

# Return degraded state when swaync-client is not installed.
if ! command -v swaync-client >/dev/null 2>&1; then
  printf '{"text":" ?","class":"warn","tooltip":"swaync-client not found"}\n'
  exit 0
fi

# Show a simple bell icon for notification center availability.
if pgrep -x swaync >/dev/null 2>&1; then
  printf '{"text":"","tooltip":"Notification Center (click to toggle)"}\n'
else
  printf '{"text":"","class":"warn","tooltip":"swaync is not running"}\n'
fi
