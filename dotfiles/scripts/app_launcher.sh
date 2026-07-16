#!/usr/bin/env bash
set -euo pipefail

# Backend selection:
# - auto (default): prefer fuzzel, then fallback to wofi
# - fuzzel: force fuzzel
# - wofi: force wofi
backend="${APP_LAUNCHER_BACKEND:-auto}"

create_fuzzel_data_overlay() {
  local base_data_home overlay_dir applications_dir tmp_root
  local source_dir application_path
  local desktop_id

  base_data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
  tmp_root="${TMPDIR:-/tmp}"
  overlay_dir="$(mktemp -d "$tmp_root/fuzzel-data-home.XXXXXX")"
  applications_dir="$overlay_dir/applications"

  mkdir -p "$applications_dir"

  # Preserve user desktop entries and user-scoped Flatpak exports while hiding
  # only the known crashy entries below. Overriding XDG_DATA_HOME without
  # copying Flatpak exports makes user Flatpak apps disappear from drun.
  for source_dir in \
    "$base_data_home/applications" \
    "$base_data_home/flatpak/exports/share/applications"
  do
    [[ -d "$source_dir" ]] || continue
    while IFS= read -r application_path; do
      ln -sfn "$application_path" "$applications_dir/$(basename "$application_path")"
    done < <(find "$source_dir" -maxdepth 1 -type f -name '*.desktop' | sort)
  done

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

create_fuzzel_launch_wrapper() {
  local overlay_dir="$1"
  local base_data_home="$2"
  local original_xdg_data_dirs="$3"
  local wrapper_path="$overlay_dir/launch-clean-env.sh"

  cat > "$wrapper_path" <<EOF
#!/usr/bin/env bash
set -euo pipefail

export XDG_DATA_HOME="$base_data_home"
export XDG_DATA_DIRS="$original_xdg_data_dirs"
exec "\$@"
EOF

  chmod +x "$wrapper_path"
  printf '%s\n' "$wrapper_path"
}

run_fuzzel() {
  local overlay_dir base_data_home original_xdg_data_dirs launch_wrapper

  command -v fuzzel >/dev/null 2>&1 || return 1
  pgrep -x fuzzel >/dev/null 2>&1 && exit 0

  base_data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
  original_xdg_data_dirs="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
  overlay_dir="$(create_fuzzel_data_overlay)"
  launch_wrapper="$(create_fuzzel_launch_wrapper "$overlay_dir" "$base_data_home" "$original_xdg_data_dirs")"
  export XDG_DATA_HOME="$overlay_dir"
  export XDG_DATA_DIRS="${base_data_home}/flatpak/exports/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
  exec fuzzel --launch-prefix="$launch_wrapper"
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
