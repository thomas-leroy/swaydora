#!/usr/bin/env bash
set -euo pipefail

# Open graphical power screen.
if ! command -v wlogout >/dev/null 2>&1; then
  notify-send "Power menu" "wlogout is not installed"
  exit 1
fi

# Build possible wlogout theme file locations.
declare -a CANDIDATES=()
if [[ -f "$HOME/.config/wlogout/layout" && -f "$HOME/.config/wlogout/style.css" ]]; then
  CANDIDATES+=("$HOME/.config/wlogout/layout|$HOME/.config/wlogout/style.css")
fi
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
if [[ -f "$repo_root/wlogout/layout" && -f "$repo_root/wlogout/style.css" ]]; then
  CANDIDATES+=("$repo_root/wlogout/layout|$repo_root/wlogout/style.css")
fi

# Toggle behavior: if already open, close it.
if pgrep -x wlogout >/dev/null 2>&1; then
  pkill -x wlogout
  exit 0
fi

# Try explicit config paths and use the first one that works.
err_file="$(mktemp)"
for entry in "${CANDIDATES[@]}"; do
  layout_file="${entry%%|*}"
  css_file="${entry#*|}"
  if wlogout --buttons-per-row 2 --layout "$layout_file" --css "$css_file" 2>"$err_file"; then
    rm -f "$err_file"
    exit 0
  fi
  if wlogout --layout "$layout_file" --css "$css_file" 2>"$err_file"; then
    rm -f "$err_file"
    exit 0
  fi
done

err_msg="$(head -n 1 "$err_file" 2>/dev/null || true)"
rm -f "$err_file"
if [[ -n "${err_msg:-}" ]]; then
  notify-send "Power menu" "Unable to start wlogout: $err_msg"
else
  notify-send "Power menu" "Unable to start wlogout"
fi
exit 1
