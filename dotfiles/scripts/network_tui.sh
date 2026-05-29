#!/usr/bin/env bash
set -euo pipefail

if command -v nm-connection-editor >/dev/null 2>&1; then
  exec nm-connection-editor
fi

notify-send "Network" "nm-connection-editor is not installed"
exit 127
