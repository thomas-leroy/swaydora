#!/usr/bin/env bash
set -euo pipefail

# Keep a single tray instance across Sway reloads.
command -v udiskie >/dev/null 2>&1 || exit 0

mapfile -t current_args < <(ps -o args= -u "$UID" -C udiskie 2>/dev/null || true)

if [[ "${#current_args[@]}" -eq 1 && "${current_args[0]}" == "udiskie --tray" ]]; then
  exit 0
fi

if [[ "${#current_args[@]}" -gt 0 ]]; then
  pkill -xu "$UID" -x udiskie >/dev/null 2>&1 || true
  sleep 0.2
fi

exec udiskie --tray
