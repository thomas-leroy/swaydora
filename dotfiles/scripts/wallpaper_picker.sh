#!/usr/bin/env bash
set -euo pipefail

# Open Waypaper with a fuzzy category selector for Noctax wallpapers.
NOCTAX_WALLS_DIR="${NOCTAX_WALLS_DIR:-$HOME/.local/share/wallpapers/Noctax-Wallpapers}"
BACKEND="${WAYPAPER_BACKEND:-swww}"
WAYPAPER_BIN="${WAYPAPER_BIN:-}"

log_err() {
  notify-send "Wallpaper" "$1"
}

main() {
  local menu_launcher="${XDG_CONFIG_HOME:-$HOME/.config}/scripts/menu_launcher.sh"
  [[ -x "$menu_launcher" ]] || {
    log_err 'menu launcher is required for wallpaper picker'
    exit 1
  }
  if [[ -z "$WAYPAPER_BIN" ]]; then
    if command -v waypaper >/dev/null 2>&1; then
      WAYPAPER_BIN="$(command -v waypaper)"
    elif [[ -x "$HOME/.local/bin/waypaper" ]]; then
      WAYPAPER_BIN="$HOME/.local/bin/waypaper"
    fi
  fi
  [[ -n "$WAYPAPER_BIN" ]] || {
    log_err 'waypaper is required (not found in PATH or ~/.local/bin)'
    exit 1
  }

  [[ -d "$NOCTAX_WALLS_DIR" ]] || {
    log_err "Wallpaper source not found: $NOCTAX_WALLS_DIR"
    exit 1
  }

  local -a categories=() items=()
  local entry category selected
  declare -A path_by_label
  if command -v fd >/dev/null 2>&1; then
    mapfile -t categories < <(fd -HI -t d -d 1 . "$NOCTAX_WALLS_DIR" | sort -u)
  else
    mapfile -t categories < <(find "$NOCTAX_WALLS_DIR" -mindepth 1 -maxdepth 1 -type d | sort -u)
  fi

  [[ "${#categories[@]}" -gt 0 ]] || {
    log_err "No categories found in $NOCTAX_WALLS_DIR"
    exit 1
  }

  for entry in "${categories[@]}"; do
    category="${entry#"$NOCTAX_WALLS_DIR/"}"
    items+=("$category")
    path_by_label["$category"]="$entry"
  done

  selected="$(printf '%s\n' "${items[@]}" | "$menu_launcher" --prompt 'Wallpaper category')"

  [[ -n "${selected:-}" ]] || exit 0
  selected="${path_by_label[$selected]:-}"
  [[ -d "$selected" ]] || exit 0

  exec "$WAYPAPER_BIN" --folder "$selected" --backend "$BACKEND"
}

main "$@"
