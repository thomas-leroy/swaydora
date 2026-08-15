#!/usr/bin/env bash
set -euo pipefail

if ! command -v waybar >/dev/null 2>&1; then
  printf 'waybar_start: waybar not found in PATH\n' >&2
  exit 127
fi

TZ="${SWAYDORA_WAYBAR_TZ:-Europe/Paris}" exec waybar
