#!/usr/bin/env bash
set -euo pipefail

# Fuzzy wallpaper picker (fuzzel-only, for performance testing).
WALLPAPERS_DIR="${WALLPAPERS_DIR:-${NOCTAX_WALLS_DIR:-$HOME/.local/share/wallpapers/Wallpapers}}"
STATE_FILE="${STATE_FILE:-$HOME/.config/sway/.current_wallpaper}"

log_err() {
  notify-send "Wallpaper" "$1"
}

is_supported_image() {
  local file="$1"
  case "${file,,}" in
    *.jpg|*.jpeg|*.png|*.webp|*.bmp|*.gif|*.tif|*.tiff|*.svg)
      return 0
      ;;
  esac
  return 1
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

    if swww img "$image" --transition-type simple --transition-duration 0.4 >/dev/null 2>&1; then
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

  local -a candidates=() items=() item_paths=()
  local entry selected selected_path rel dir file label
  declare -A path_by_label

  if command -v fd >/dev/null 2>&1 && command -v sort >/dev/null 2>&1; then
    mapfile -d '' -t candidates < <(fd -HI -t f -0 . "$WALLPAPERS_DIR" | sort -z)
  elif command -v fd >/dev/null 2>&1; then
    mapfile -d '' -t candidates < <(fd -HI -t f -0 . "$WALLPAPERS_DIR")
  elif command -v sort >/dev/null 2>&1; then
    mapfile -d '' -t candidates < <(find "$WALLPAPERS_DIR" -type f -print0 | sort -z)
  else
    mapfile -d '' -t candidates < <(find "$WALLPAPERS_DIR" -type f -print0)
  fi

  for entry in "${candidates[@]}"; do
    is_supported_image "$entry" || continue
    rel="${entry#"$WALLPAPERS_DIR/"}"
    file="${rel##*/}"
    dir="${rel%/*}"
    [[ "$dir" == "$rel" ]] && dir='.'
    label="$dir - $file"
    items+=("$label")
    item_paths+=("$entry")
    path_by_label["$label"]="$entry"
  done

  [[ "${#items[@]}" -gt 0 ]] || {
    log_err "No image files found in $WALLPAPERS_DIR"
    exit 1
  }

  pgrep -x fuzzel >/dev/null 2>&1 && exit 0
  selected="$(
    {
      local i
      for i in "${!items[@]}"; do
        # dmenu row with icon metadata. If unsupported, fuzzel ignores it.
        printf '%s\0icon\x1f%s\n' "${items[$i]}" "${item_paths[$i]}"
      done
    } | fuzzel --dmenu --prompt 'Wallpaper > '
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
