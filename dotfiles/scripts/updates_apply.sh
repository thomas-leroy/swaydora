#!/usr/bin/env bash
set -euo pipefail

# Run full system upgrade in Kitty.
# Sway rule in config matches this title and makes it floating/centered.
if command -v kitty >/dev/null 2>&1; then
  kitty --title "System Updates" sh -lc \
    'sudo dnf upgrade --refresh; printf "\nDone. Press Enter to close..."; read -r _'
  exit 0
fi

notify-send "Updates" "Kitty is not available. Run: sudo dnf upgrade --refresh"
exit 1
