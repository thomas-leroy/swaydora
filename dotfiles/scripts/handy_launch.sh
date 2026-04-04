#!/usr/bin/env bash
set -euo pipefail

if ! command -v handy >/dev/null 2>&1; then
  notify-send "Handy" "handy is not installed"
  exit 1
fi

if ! command -v wtype >/dev/null 2>&1 && ! command -v dotool >/dev/null 2>&1; then
  notify-send "Handy" "Wayland text input works best with wtype or dotool"
fi

nohup handy >/dev/null 2>&1 &
