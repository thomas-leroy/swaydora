#!/usr/bin/env bash
set -euo pipefail

if command -v thunderbird >/dev/null 2>&1; then
  exec thunderbird
fi

notify-send "Mail" "Thunderbird is not installed"
exit 1
