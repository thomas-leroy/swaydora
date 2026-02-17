#!/usr/bin/env bash
set -euo pipefail

# Print consistent log messages for this script.
log() {
  printf '[waybar-reload-setup] %s\n' "$*"
}

main() {
  # Source runtime helper from shared dotfiles location.
  local src="${DOTFILES_SRC:-/mnt/dotfiles/dotfiles}/scripts/reload_env.sh"
  local dst="$HOME/.local/bin/reload-waybar"

  # Ensure local bin directory exists.
  mkdir -p "$HOME/.local/bin"

  # Create helper symlink when source exists.
  if [[ -e "$src" ]]; then
    ln -sfn "$src" "$dst"
    chmod +x "$src"
    log "installed helper symlink: $dst -> $src"
  else
    log "runtime script not found at $src, skipping"
  fi

  # Remind user how to bind this helper.
  log 'you can bind this helper in sway: bindsym $mod+Shift+r exec ~/.local/bin/reload-waybar'
}

# Entrypoint.
main "$@"
