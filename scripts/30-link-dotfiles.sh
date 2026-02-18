#!/usr/bin/env bash
set -euo pipefail

# Default source path for shared dotfiles mount inside VM.
DOTFILES_SRC="${DOTFILES_SRC:-/mnt/dotfiles/dotfiles}"

# Print consistent log messages for this script.
log() {
  printf '[link] %s\n' "$*"
}

# Build a backup path, with timestamp when a backup already exists.
backup_path() {
  local path="$1"
  local backup="${path}.bak"
  if [[ -e "$backup" || -L "$backup" ]]; then
    backup="${path}.bak.$(date +%Y%m%d%H%M%S)"
  fi
  printf '%s\n' "$backup"
}

# Link one config directory, preserving previous non-symlink config as backup.
link_one() {
  local name="$1"
  local src="$DOTFILES_SRC/$name"
  local dst="$HOME/.config/$name"

  # Skip missing source directories.
  if [[ ! -e "$src" ]]; then
    log "source missing, skipping: $src"
    return 0
  fi

  # Backup existing real directory/file before replacing with symlink.
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    local backup
    backup="$(backup_path "$dst")"
    log "backing up existing config: $dst -> $backup"
    mv "$dst" "$backup"
  fi

  # Force-create/replace symlink target.
  log "linking: $dst -> $src"
  ln -sfn "$src" "$dst"
}

main() {
  # Ensure XDG config root exists.
  mkdir -p "$HOME/.config"

  # Stop early if mount/source is unavailable.
  if [[ ! -d "$DOTFILES_SRC" ]]; then
    printf '[link] dotfiles source directory not found: %s\n' "$DOTFILES_SRC" >&2
    exit 1
  fi

  # Link all managed config directories.
  for dir in sway waybar mako swaync wofi fuzzel kitty wlogout zsh fastfetch atuin environment.d scripts; do
    link_one "$dir"
  done

  # Create local override files if missing.
  touch "$HOME/.config/sway/local.conf" "$HOME/.config/waybar/local.css" "$HOME/.config/mako/local.conf" "$HOME/.config/swaync/local.css"
  log 'ensured local override files exist (untracked by git)'

  log 'done'
}

# Entrypoint.
main "$@"
