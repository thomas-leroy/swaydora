#!/usr/bin/env bash
set -euo pipefail

# Sync wallpapers from dharmx/walls into local Sway wallpaper directory.
# Default behavior uses sparse checkout for selected categories to avoid multi-GB download.
#
# Env vars:
#   WALLS_REPO_URL   (default: https://github.com/dharmx/walls.git)
#   WALLS_DEST       (default: ~/.config/sway/wallpapers/dharmx-walls)
#   WALLS_FULL       (1=full clone, 0=sparse mode; default: 0)
#   WALLS_CATEGORIES (space-separated dirs in sparse mode)

WALLS_REPO_URL="${WALLS_REPO_URL:-https://github.com/dharmx/walls.git}"
WALLS_DEST="${WALLS_DEST:-$HOME/.config/sway/wallpapers/dharmx-walls}"
WALLS_FULL="${WALLS_FULL:-0}"
WALLS_CATEGORIES="${WALLS_CATEGORIES:-nature abstract minimal nord chillop mountain}"

log() {
  printf '[walls-sync] %s\n' "$*"
}

ensure_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf '[walls-sync] missing command: %s\n' "$1" >&2
    exit 1
  }
}

setup_sparse_checkout() {
  log "configuring sparse checkout categories: ${WALLS_CATEGORIES}"
  git -C "$WALLS_DEST" sparse-checkout init --cone
  # shellcheck disable=SC2086
  git -C "$WALLS_DEST" sparse-checkout set $WALLS_CATEGORIES
}

clone_repo() {
  mkdir -p "$(dirname "$WALLS_DEST")"

  if [[ "$WALLS_FULL" == '1' ]]; then
    log 'cloning full wallpaper repository (this can be very large)'
    git clone "$WALLS_REPO_URL" "$WALLS_DEST"
    return 0
  fi

  log 'cloning wallpaper repository in sparse mode'
  git clone --filter=blob:none --no-checkout "$WALLS_REPO_URL" "$WALLS_DEST"
  setup_sparse_checkout
  git -C "$WALLS_DEST" checkout main || git -C "$WALLS_DEST" checkout master
}

update_repo() {
  if [[ "$WALLS_FULL" == '1' ]]; then
    log 'updating full wallpaper repository'
    git -C "$WALLS_DEST" pull --ff-only
    return 0
  fi

  setup_sparse_checkout
  log 'updating sparse wallpaper repository'
  git -C "$WALLS_DEST" pull --ff-only
}

main() {
  ensure_cmd git

  if [[ -d "$WALLS_DEST/.git" ]]; then
    update_repo
  else
    clone_repo
  fi

  log "done; wallpapers available under: $WALLS_DEST"
  log 'tip: run ~/.config/scripts/wallpaper_picker.sh and search by folder/file name'
}

main "$@"
