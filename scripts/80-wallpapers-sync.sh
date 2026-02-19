#!/usr/bin/env bash
set -euo pipefail

# Sync wallpapers from dharmx/walls into a local wallpapers folder.
#
# Env vars:
#   WALLS_REPO_URL   (default: https://github.com/dharmx/walls.git)
#   WALLS_DEST       (default: ~/.local/share/wallpapers/Wallpapers)
#   WALLS_WORKDIR    (default: ~/.cache/walls-sync/dharmx-walls)
#   WALLS_FULL       (1=full clone, 0=sparse mode; default: 0)
#   WALLS_CATEGORIES (space-separated dirs in sparse mode; default: abstract)

WALLS_REPO_URL="${WALLS_REPO_URL:-https://github.com/dharmx/walls.git}"
WALLS_DEST="${WALLS_DEST:-$HOME/.local/share/wallpapers/Wallpapers}"
WALLS_WORKDIR="${WALLS_WORKDIR:-$HOME/.cache/walls-sync/dharmx-walls}"
WALLS_FULL="${WALLS_FULL:-0}"
WALLS_CATEGORIES="${WALLS_CATEGORIES:-abstract}"

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
  git -C "$WALLS_WORKDIR" sparse-checkout init --cone
  # shellcheck disable=SC2086
  git -C "$WALLS_WORKDIR" sparse-checkout set $WALLS_CATEGORIES
}

clone_repo() {
  mkdir -p "$(dirname "$WALLS_WORKDIR")"
  if [[ -d "$WALLS_WORKDIR" && ! -d "$WALLS_WORKDIR/.git" ]]; then
    rm -rf "$WALLS_WORKDIR"
  fi

  if [[ "$WALLS_FULL" == '1' ]]; then
    log 'cloning full wallpaper repository (this can be very large)'
    git clone "$WALLS_REPO_URL" "$WALLS_WORKDIR"
    return 0
  fi

  log 'cloning wallpaper repository in sparse mode'
  git clone --filter=blob:none --no-checkout "$WALLS_REPO_URL" "$WALLS_WORKDIR"
  setup_sparse_checkout
  git -C "$WALLS_WORKDIR" checkout main || git -C "$WALLS_WORKDIR" checkout master
}

update_repo() {
  if [[ "$WALLS_FULL" == '1' ]]; then
    log 'updating full wallpaper repository'
    git -C "$WALLS_WORKDIR" sparse-checkout disable >/dev/null 2>&1 || true
    git -C "$WALLS_WORKDIR" pull --ff-only
    return 0
  fi

  setup_sparse_checkout
  log 'updating sparse wallpaper repository'
  git -C "$WALLS_WORKDIR" pull --ff-only
}

export_snapshot() {
  mkdir -p "$WALLS_DEST"

  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete --exclude '.git' "$WALLS_WORKDIR"/ "$WALLS_DEST"/
  else
    log 'rsync not found; copying files without cleanup'
    cp -a "$WALLS_WORKDIR"/. "$WALLS_DEST"/
  fi

  rm -rf "$WALLS_DEST/.git"
}

main() {
  ensure_cmd git

  if [[ -d "$WALLS_WORKDIR/.git" ]]; then
    update_repo
  else
    clone_repo
  fi

  export_snapshot
  log "done; wallpapers available under: $WALLS_DEST"
  log 'tip: run ~/.config/scripts/wallpaper_picker.sh to search/apply a wallpaper with Wofi'
}

main "$@"
