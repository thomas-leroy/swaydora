#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/logging.sh"
setup_logger link

# Default source path for shared dotfiles mount inside VM.
DOTFILES_SRC="${DOTFILES_SRC:-/mnt/dotfiles/dotfiles}"
BACKUP_CONFIG_ROOT="${BACKUP_CONFIG_ROOT:-$HOME/.backup_configs}"
MANAGED_CONFIGS=(sway waybar mako swaync wofi fuzzel kitty wlogout zsh fastfetch atuin environment.d scripts xdg-desktop-portal)
MANAGED_CONFIG_FILES=(mimeapps.list)
BACKUP_DIR_CREATED=''
BACKUP_ITEMS=()
LINKED_ITEMS=()
LOCAL_OVERRIDES=()
SKIPPED_ITEMS=()

# Build a backup path, with timestamp when a backup already exists.
backup_path() {
  local path="$1"
  local backup="${path}.bak"
  if [[ -e "$backup" || -L "$backup" ]]; then
    backup="${path}.bak.$(date +%Y%m%d%H%M%S)"
  fi
  printf '%s\n' "$backup"
}

# Backup managed config files/directories that already exist before linking.
backup_config() {
  local timestamp backup_dir item src dst backed_up=0

  timestamp="$(date +%Y%m%d_%H%M%S)"
  backup_dir="$BACKUP_CONFIG_ROOT/config_backup_${timestamp}"

  mkdir -p "$backup_dir/.config"

  for item in "${MANAGED_CONFIGS[@]}"; do
    src="$DOTFILES_SRC/$item"
    dst="$HOME/.config/$item"
    if [[ -e "$src" && ( -e "$dst" || -L "$dst" ) ]]; then
      log "backing up current config: $dst -> $backup_dir/.config/$item"
      cp -a "$dst" "$backup_dir/.config/"
      BACKUP_ITEMS+=("$dst")
      backed_up=1
    fi
  done

  for item in "${MANAGED_CONFIG_FILES[@]}"; do
    src="$DOTFILES_SRC/$item"
    dst="$HOME/.config/$item"
    if [[ -e "$src" && ( -e "$dst" || -L "$dst" ) ]]; then
      log "backing up current config file: $dst -> $backup_dir/.config/$item"
      cp -a "$dst" "$backup_dir/.config/"
      BACKUP_ITEMS+=("$dst")
      backed_up=1
    fi
  done

  if [[ "$backed_up" == '0' ]]; then
    rmdir "$backup_dir/.config" "$backup_dir"
    log_warn 'no existing managed configs to back up'
    return 0
  fi

  BACKUP_DIR_CREATED="$backup_dir"
  log_success "backup created: $backup_dir"
}

# Link one config directory, preserving previous non-symlink config as backup.
link_one() {
  local name="$1"
  local src="$DOTFILES_SRC/$name"
  local dst="$HOME/.config/$name"

  # Skip missing source directories.
  if [[ ! -e "$src" ]]; then
    log_warn "source missing, skipping: $src"
    SKIPPED_ITEMS+=("$src")
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
  LINKED_ITEMS+=("$dst -> $src")
}

ensure_local_override() {
  local path="$1"
  local parent="${path%/*}"

  if [[ ! -d "$parent" ]]; then
    log_warn "override parent missing, skipping: $path"
    return 0
  fi

  touch "$path"
  LOCAL_OVERRIDES+=("$path")
}

main() {
  # Ensure XDG config root exists.
  mkdir -p "$HOME/.config"

  # Stop early if mount/source is unavailable.
  if [[ ! -d "$DOTFILES_SRC" ]]; then
    log_error "dotfiles source directory not found: $DOTFILES_SRC"
    exit 1
  fi

  # Link all managed config directories.
  backup_config

  for dir in "${MANAGED_CONFIGS[@]}"; do
    link_one "$dir"
  done

  # Link top-level XDG files.
  if [[ -e "$DOTFILES_SRC/mimeapps.list" ]]; then
    log "linking: $HOME/.config/mimeapps.list -> $DOTFILES_SRC/mimeapps.list"
    ln -sfn "$DOTFILES_SRC/mimeapps.list" "$HOME/.config/mimeapps.list"
    LINKED_ITEMS+=("$HOME/.config/mimeapps.list -> $DOTFILES_SRC/mimeapps.list")
  fi

  # Create local override files if missing.
  ensure_local_override "$HOME/.config/sway/local.conf"
  ensure_local_override "$HOME/.config/waybar/local.css"
  ensure_local_override "$HOME/.config/mako/local.conf"
  ensure_local_override "$HOME/.config/swaync/local.css"
  log 'ensured local override files exist (untracked by git)'

  log 'summary:'
  if [[ -n "$BACKUP_DIR_CREATED" ]]; then
    log "backup created: $BACKUP_DIR_CREATED (${#BACKUP_ITEMS[@]} item(s))"
  else
    log 'backup created: none needed'
  fi
  log "configs linked: ${#LINKED_ITEMS[@]}"
  if [[ "${#LINKED_ITEMS[@]}" -gt 0 ]]; then
    printf '  - %s\n' "${LINKED_ITEMS[@]}"
  fi
  log "local override files ensured: ${#LOCAL_OVERRIDES[@]}"
  if [[ "${#LOCAL_OVERRIDES[@]}" -gt 0 ]]; then
    printf '  - %s\n' "${LOCAL_OVERRIDES[@]}"
  fi
  log "sources skipped: ${#SKIPPED_ITEMS[@]}"
  log_success 'done'
}

# Entrypoint.
main "$@"
