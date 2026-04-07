#!/usr/bin/env bash
set -euo pipefail

# Install oh-my-zsh for current user in unattended mode.
# Optional env vars:
#   SET_DEFAULT_SHELL=1   -> set zsh as default shell (default: 1)
#   KEEP_ZSHRC=1          -> keep existing ~/.zshrc when installing (default: 1)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/logging.sh"
setup_logger oh-my-zsh

SET_DEFAULT_SHELL="${SET_DEFAULT_SHELL:-1}"
KEEP_ZSHRC_OPT="${KEEP_ZSHRC:-1}"

run_as_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

ensure_package() {
  local pkg="$1"
  if rpm -q "$pkg" >/dev/null 2>&1; then
    log_success "already installed: $pkg"
    return 0
  fi

  if dnf -q list --available "$pkg" >/dev/null 2>&1 || dnf -q list --installed "$pkg" >/dev/null 2>&1; then
    log "installing package: $pkg"
    run_as_root dnf install -y "$pkg"
    return 0
  fi

  log_error "required package not available: $pkg"
  exit 1
}

install_oh_my_zsh() {
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    log_success 'oh-my-zsh already installed'
    return 0
  fi

  if ! command -v curl >/dev/null 2>&1; then
    log_error 'curl is required but not found'
    exit 1
  fi

  log 'installing oh-my-zsh (unattended)'
  RUNZSH=no CHSH=no KEEP_ZSHRC="$KEEP_ZSHRC_OPT" sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

set_default_shell_if_requested() {
  [[ "$SET_DEFAULT_SHELL" == '1' ]] || {
    log_warn 'skipping default shell change (SET_DEFAULT_SHELL!=1)'
    return 0
  }

  local zsh_path
  zsh_path="$(command -v zsh || true)"
  if [[ -z "$zsh_path" ]]; then
    log_error 'zsh not found, cannot set default shell'
    return 1
  fi

  local current_shell
  current_shell="$(getent passwd "$USER" | cut -d: -f7 || true)"
  if [[ "$current_shell" == "$zsh_path" ]]; then
    log_success "default shell already set to $zsh_path"
    return 0
  fi

  log "setting default shell to $zsh_path for user $USER (current: ${current_shell:-unknown})"
  run_as_root usermod -s "$zsh_path" "$USER"
  log_success 'default shell updated; logout/login required'
}

main() {
  command -v dnf >/dev/null 2>&1 || {
    log_error 'dnf not found'
    exit 1
  }

  ensure_package zsh
  ensure_package curl
  install_oh_my_zsh
  set_default_shell_if_requested
  log_success 'done'
}

main "$@"
