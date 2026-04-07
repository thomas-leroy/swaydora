#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/logging.sh"
setup_logger waybar-reload-setup
INSTALLED_LINKS=()
SKIPPED_ITEMS=()

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
    INSTALLED_LINKS+=("$dst -> $src")
    log_success "installed helper symlink: $dst -> $src"
  else
    log_warn "runtime script not found at $src, skipping"
    SKIPPED_ITEMS+=("$src")
  fi

  # Remind user how to bind this helper.
  log 'you can bind this helper in sway: bindsym $mod+Shift+r exec ~/.local/bin/reload-waybar'
  log 'summary:'
  log "helper links installed: ${#INSTALLED_LINKS[@]}"
  if [[ "${#INSTALLED_LINKS[@]}" -gt 0 ]]; then
    printf '  - %s\n' "${INSTALLED_LINKS[@]}"
  fi
  log "items skipped: ${#SKIPPED_ITEMS[@]}"
  log_success 'done'
}

# Entrypoint.
main "$@"
