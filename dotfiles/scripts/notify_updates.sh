#!/usr/bin/env bash
set -euo pipefail

# Path to updates counter helper.
count="$HOME/.config/scripts/updates_check.sh"

# Notify current update count when helper is executable.
if [[ -x "$count" ]]; then
  value="$($count --plain)"
  notify-send "System updates" "${value} update(s) available"
else
  notify-send "System updates" "updates_check.sh not executable"
fi
