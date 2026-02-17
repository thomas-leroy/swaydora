#!/usr/bin/env bash
set -euo pipefail

# Run full system upgrade with fresh metadata.
run_upgrade() {
  sudo dnf upgrade --refresh
}

# If script is run in an interactive terminal, run upgrade directly.
if [[ -t 1 ]]; then
  run_upgrade
  exit 0
fi

# Otherwise try opening a terminal emulator and run the upgrade there.
if command -v wezterm >/dev/null 2>&1; then
  wezterm start -- bash -lc 'sudo dnf upgrade --refresh; read -rp "Press Enter to close..."' &
elif command -v alacritty >/dev/null 2>&1; then
  alacritty -e bash -lc 'sudo dnf upgrade --refresh; read -rp "Press Enter to close..."' &
else
  notify-send "Updates" "Open a terminal and run: sudo dnf upgrade --refresh"
fi
