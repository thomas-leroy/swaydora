#!/usr/bin/env bash
set -euo pipefail

# Backend selection:
# - auto (default): prefer fuzzel, then fallback to wofi
# - fuzzel: force fuzzel
# - wofi: force wofi
backend="${APP_LAUNCHER_BACKEND:-auto}"

create_fuzzel_data_overlay() {
  local base_data_home overlay_dir applications_dir local_applications_dir tmp_root
  local desktop_id

  base_data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
  tmp_root="${TMPDIR:-/tmp}"
  overlay_dir="$(mktemp -d "$tmp_root/fuzzel-data-home.XXXXXX")"
  applications_dir="$overlay_dir/applications"
  local_applications_dir="$base_data_home/applications"

  mkdir -p "$applications_dir"

  if [[ -d "$local_applications_dir" ]]; then
    local application_path
    while IFS= read -r application_path; do
      ln -s "$application_path" "$applications_dir/$(basename "$application_path")"
    done < <(find "$local_applications_dir" -maxdepth 1 -type f -name '*.desktop' | sort)
  fi

  # Mask a few hidden desktop entries that reference out-of-theme SVG icons and
  # have been seen to crash fuzzel's icon rasterizer during drun indexing.
  for desktop_id in \
    ibus-setup-libpinyin.desktop \
    ibus-setup-libbopomofo.desktop \
    ibus-setup-table.desktop \
    io.snapcraft.SessionAgent.desktop
  do
    cat > "$applications_dir/$desktop_id" <<'EOF'
[Desktop Entry]
Hidden=true
EOF
  done

  printf '%s\n' "$overlay_dir"
}

run_fuzzel() {
  local overlay_dir

  command -v fuzzel >/dev/null 2>&1 || return 1
  pgrep -x fuzzel >/dev/null 2>&1 && exit 0

  overlay_dir="$(create_fuzzel_data_overlay)"
  export XDG_DATA_HOME="$overlay_dir"
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
