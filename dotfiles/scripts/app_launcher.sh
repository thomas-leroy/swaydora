#!/usr/bin/env bash
set -euo pipefail

# Backend selection:
# - auto (default): prefer fuzzel, then fallback to wofi
# - fuzzel: force fuzzel
# - wofi: force wofi
backend="${APP_LAUNCHER_BACKEND:-auto}"

run_fuzzel() {
  command -v fuzzel >/dev/null 2>&1 || return 1
  pgrep -x fuzzel >/dev/null 2>&1 && exit 0
  exec fuzzel
}

run_wofi() {
  command -v wofi >/dev/null 2>&1 || return 1
  pgrep -x wofi >/dev/null 2>&1 && exit 0

  local args=(
    --show drun
    --prompt Apps
    --allow-images
    --insensitive
    --matching contains
    --sort-order alphabetical
  )

  # Hide desktop actions when supported to avoid indented sub-entries.
  if wofi --help 2>/dev/null | grep -q -- '--no-actions'; then
    args+=(--no-actions)
  fi

  exec wofi "${args[@]}"
}

case "$backend" in
  auto)
    run_fuzzel || run_wofi
    ;;
  fuzzel)
    run_fuzzel
    ;;
  wofi)
    run_wofi
    ;;
  *)
    notify-send "Launcher" "unsupported backend: $backend"
    exit 2
    ;;
esac

notify-send "Launcher" "no launcher found (expected fuzzel or wofi)"
exit 127
