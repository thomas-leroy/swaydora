#!/usr/bin/env bash
set -euo pipefail

# Fuzzy wallpaper picker (fuzzel-only, for performance testing).
WALLPAPERS_DIR="${WALLPAPERS_DIR:-${NOCTAX_WALLS_DIR:-$HOME/.local/share/wallpapers/Wallpapers}}"
STATE_FILE="${STATE_FILE:-$HOME/.config/sway/.current_wallpaper}"
PICKER_MANIFEST="${PICKER_MANIFEST:-$HOME/.cache/wallpaper-picker/manifest.tsv}"

log_err() {
  notify-send "Wallpaper" "$1"
}

apply_wallpaper() {
  local image="$1"

  if command -v swww >/dev/null 2>&1 && command -v swww-daemon >/dev/null 2>&1; then
    if ! pgrep -x swww-daemon >/dev/null 2>&1; then
      swww-daemon >/dev/null 2>&1 &
    fi
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      swww query >/dev/null 2>&1 && break
      sleep 0.1
    done

    if swww img "$image" --transition-type wipe --transition-duration 0.4 >/dev/null 2>&1; then
      return 0
    fi
  fi

  if command -v swaybg >/dev/null 2>&1; then
    pkill -x swaybg >/dev/null 2>&1 || true
    swaybg -i "$image" -m fill >/dev/null 2>&1 &
    return 0
  fi

  return 1
}

main() {
  command -v fuzzel >/dev/null 2>&1 || {
    log_err 'fuzzel not found'
    exit 127
  }

  [[ -d "$WALLPAPERS_DIR" ]] || {
    log_err "Wallpaper source not found: $WALLPAPERS_DIR"
    exit 1
  }

  [[ -f "$PICKER_MANIFEST" ]] || {
    log_err "Wallpaper picker cache not found: $PICKER_MANIFEST"
    exit 1
  }

  local -a items=() item_paths=() item_icons=()
  local selected selected_path label image_path icon_path
  declare -A path_by_label

  while IFS=$'\t' read -r label image_path icon_path; do
    [[ -n "${label:-}" && -n "${image_path:-}" && -n "${icon_path:-}" ]] || continue
    items+=("$label")
    item_paths+=("$image_path")
    item_icons+=("$icon_path")
    path_by_label["$label"]="$image_path"
  done < "$PICKER_MANIFEST"

  [[ "${#items[@]}" -gt 0 ]] || {
    log_err "No wallpaper entries found in cache: $PICKER_MANIFEST"
    exit 1
  }

  pgrep -x fuzzel >/dev/null 2>&1 && exit 0
  selected="$(
    {
      local i
      for i in "${!items[@]}"; do
        printf '%s\0icon\x1f%s\n' "${items[$i]}" "${item_icons[$i]}"
      done
    } | fuzzel \
      --dmenu \
      --prompt 'Wallpaper > ' \
      --lines 5 \
      --width 72 \
      --line-height 80 \
      --horizontal-pad 20 \
      --vertical-pad 16 \
      --inner-pad 10
  )"

  [[ -n "${selected:-}" ]] || exit 0
  selected_path="${path_by_label[$selected]:-}"
  [[ -f "$selected_path" ]] || exit 0

  if ! apply_wallpaper "$selected_path"; then
    log_err 'No wallpaper backend available (swww/swaybg not found)'
    exit 1
  fi

  mkdir -p "$(dirname "$STATE_FILE")"
  printf '%s\n' "$selected_path" > "$STATE_FILE"
}

main "$@"
