#!/usr/bin/env bash
set -euo pipefail

# Run full system upgrade in Kitty.
# Sway rule in config matches this title and makes it floating/centered.
TITLE='System Updates'

window_exists() {
  command -v swaymsg >/dev/null 2>&1 || return 1
  if command -v jq >/dev/null 2>&1; then
    swaymsg -t get_tree 2>/dev/null | jq -e --arg t "$TITLE" '.. | objects | select(.name? == $t)' >/dev/null 2>&1
    return $?
  fi
  swaymsg -t get_tree 2>/dev/null | grep -Fq "\"name\":\"$TITLE\""
}

focus_window() {
  command -v swaymsg >/dev/null 2>&1 || return 1
  swaymsg "[title=\"^${TITLE}$\"] focus" >/dev/null 2>&1 || true
}

if window_exists; then
  focus_window
  exit 0
fi

if command -v kitty >/dev/null 2>&1; then
  kitty --title "$TITLE" sh -lc \
    'cat <<'"'"'EOF'"'"'
 ▗▄▄▖▗▖ ▗▖ ▗▄▖▗▖  ▗▖▗▄▄▄  ▗▄▖ ▗▄▄▖  ▗▄▖
▐▌   ▐▌ ▐▌▐▌ ▐▌▝▚▞▘ ▐▌  █▐▌ ▐▌▐▌ ▐▌▐▌ ▐▌
 ▝▀▚▖▐▌ ▐▌▐▛▀▜▌ ▐▌  ▐▌  █▐▌ ▐▌▐▛▀▚▖▐▛▀▜▌
▗▄▄▞▘▐▙█▟▌▐▌ ▐▌ ▐▌  ▐▙▄▄▀▝▚▄▞▘▐▌ ▐▌▐▌ ▐▌
EOF
printf "\n"
sudo dnf upgrade --refresh
printf "\nDone. Press Enter to close..."
read -r _'
  exit 0
fi

notify-send "Updates" "Kitty is not available. Run: sudo dnf upgrade --refresh"
exit 1
