#!/usr/bin/env bash
set -euo pipefail

# Install oh-my-zsh for current user without executing a remote installer.
# Optional env vars:
#   SET_DEFAULT_SHELL=1   -> set zsh as default shell (default: 1)
#   KEEP_ZSHRC=1          -> keep existing ~/.zshrc when installing (default: 1)
#   OH_MY_ZSH_REPO_URL    -> repository to clone (default: official GitHub repo)
#   OH_MY_ZSH_REF         -> branch/tag/ref to clone (default: master)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/logging.sh"
setup_logger oh-my-zsh

SET_DEFAULT_SHELL="${SET_DEFAULT_SHELL:-1}"
KEEP_ZSHRC_OPT="${KEEP_ZSHRC:-1}"
OH_MY_ZSH_REPO_URL="${OH_MY_ZSH_REPO_URL:-https://github.com/ohmyzsh/ohmyzsh.git}"
OH_MY_ZSH_REF="${OH_MY_ZSH_REF:-master}"
TEMP_DIR=''

cleanup_temp_dir() {
  if [[ -z "${TEMP_DIR:-}" ]]; then
    return 0
  fi

  log "cleaning up temporary directory: $TEMP_DIR"
  rm -rf "$TEMP_DIR"
}

trap cleanup_temp_dir EXIT

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
  local install_dir="$HOME/.oh-my-zsh"
  local clone_dir

  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    log_success 'oh-my-zsh already installed'
    return 0
  fi

  if ! command -v git >/dev/null 2>&1; then
    log_error 'git is required but not found'
    exit 1
  fi

  log "installing oh-my-zsh from git repository: ${OH_MY_ZSH_REPO_URL} (${OH_MY_ZSH_REF})"
  TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/swaydora-oh-my-zsh.XXXXXX")"
  clone_dir="$TEMP_DIR/oh-my-zsh"

  git init "$clone_dir"
  git -C "$clone_dir" remote add origin "$OH_MY_ZSH_REPO_URL"
  git -C "$clone_dir" fetch --depth=1 origin "$OH_MY_ZSH_REF"
  git -C "$clone_dir" checkout --detach FETCH_HEAD
  git -C "$clone_dir" rev-parse --verify HEAD >/dev/null
  mv "$clone_dir" "$install_dir"

  if [[ "$KEEP_ZSHRC_OPT" != '1' && -f "$install_dir/templates/zshrc.zsh-template" ]]; then
    cp "$install_dir/templates/zshrc.zsh-template" "$HOME/.zshrc"
    log 'created ~/.zshrc from oh-my-zsh template'
  fi

  log_success "oh-my-zsh installed at $install_dir ($(git -C "$install_dir" rev-parse --short HEAD))"
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
  ensure_package git
  install_oh_my_zsh
  set_default_shell_if_requested
  log_success 'done'
}

main "$@"
