#!/usr/bin/env bash
set -euo pipefail

# Interactive wallpaper picker using fuzzel with persistent selection.
# WALLPAPER_DIRS is a colon-separated list of directories to scan.
WALLPAPER_DIRS="${WALLPAPER_DIRS:-$HOME/.config/sway/wallpapers:$HOME/.local/share/wallpapers}"
DEFAULT_WALLPAPER="$HOME/.config/sway/default-wallpaper.svg"
STATE_FILE="$HOME/.config/sway/.current_wallpaper"

log_err() {
  notify-send "Wallpaper" "$1"
}

list_wallpapers() {
  local dir
  IFS=':' read -r -a dirs <<<"$WALLPAPER_DIRS"
  for dir in "${dirs[@]}"; do
    [[ -d "$dir" ]] || continue
    if command -v fd >/dev/null 2>&1; then
      fd -HI -t f -e jpg -e jpeg -e png -e webp -e bmp -e gif -e svg . "$dir" 2>/dev/null
    else
      find "$dir" -type f \( \
        -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o \
        -iname '*.bmp' -o -iname '*.gif' -o -iname '*.svg' \
      \) 2>/dev/null
    fi
  done
}

apply_wallpaper() {
  local wp="$1"

  if command -v swww >/dev/null 2>&1; then
    # Ensure daemon is available.
    if ! pgrep -x swww-daemon >/dev/null 2>&1; then
      swww-daemon >/dev/null 2>&1 &
      sleep 0.2
    fi
    swww img "$wp" --transition-type simple --transition-duration 0.4
    return 0
  fi

  if command -v swaybg >/dev/null 2>&1; then
    pkill -x swaybg >/dev/null 2>&1 || true
    swaybg -i "$wp" -m fill >/dev/null 2>&1 &
    return 0
  fi

  return 1
}

main() {
  command -v fuzzel >/dev/null 2>&1 || {
    log_err 'fuzzel is required for wallpaper picker'
    exit 1
  }

  mkdir -p "$HOME/.config/sway/wallpapers" "$HOME/.local/share/wallpapers"

  # Sort and deduplicate to keep the picker stable when roots overlap.
  mapfile -t wallpapers < <(list_wallpapers | sort -u)

  # Always include fallback default wallpaper if present.
  if [[ -f "$DEFAULT_WALLPAPER" ]]; then
    wallpapers+=("$DEFAULT_WALLPAPER")
  fi

  if [[ "${#wallpapers[@]}" -eq 0 ]]; then
    log_err "No wallpapers found in $WALLPAPER_DIRS"
    exit 1
  fi

  # Build relative labels for better fuzzy search by folder/name.
  labels=()
  declare -A path_by_label
  local wp label
  for wp in "${wallpapers[@]}"; do
    if [[ "$wp" == "$HOME/.config/sway/wallpapers/"* ]]; then
      label="config/${wp#"$HOME/.config/sway/wallpapers/"}"
    elif [[ "$wp" == "$HOME/.local/share/wallpapers/"* ]]; then
      label="local/${wp#"$HOME/.local/share/wallpapers/"}"
    elif [[ "$wp" == "$HOME/.config/sway/"* ]]; then
      label="sway/${wp#"$HOME/.config/sway/"}"
    else
      label="$(basename "$wp")"
    fi

    labels+=("$label")
    path_by_label["$label"]="$wp"
  done

  choice="$(printf '%s\n' "${labels[@]}" | sort -u | fuzzel --dmenu --prompt 'Wallpaper')"
  [[ -n "$choice" ]] || exit 0

  selected="${path_by_label[$choice]:-}"
  [[ -n "$selected" && -f "$selected" ]] || {
    log_err 'Selected wallpaper is invalid'
    exit 1
  }

  if apply_wallpaper "$selected"; then
    printf '%s\n' "$selected" > "$STATE_FILE"
    notify-send "Wallpaper" "Applied: $(basename "$selected")"
    exit 0
  fi

  log_err 'No wallpaper backend available (need swww or swaybg)'
  exit 1
}

main "$@"
