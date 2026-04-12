#!/usr/bin/env bash

ensure_handy_installed() {
  if command -v handy >/dev/null 2>&1; then
    packages_info 'Handy already installed'
    return 0
  fi

  if pkg_is_available handy; then
    install_pkg_now handy
    return 0
  fi

  packages_info "installing Handy from direct RPM: ${HANDY_RPM_URL}"
  record_direct_package_install "$HANDY_RPM_URL"
  run_as_root dnf install -y "$HANDY_RPM_URL"
}

ensure_bluetuith_installed() {
  local install_dir archive_path binary_path launcher_path tmp_dir

  if command -v bluetuith >/dev/null 2>&1; then
    packages_info 'Bluetuith already installed'
    return 0
  fi

  if pkg_is_available bluetuith; then
    install_pkg_now bluetuith
    return 0
  fi

  require_cmd curl
  require_cmd tar

  install_dir="$HOME/.local/opt/bluetuith"
  archive_path="$TEMP_DIR/bluetuith.tar.gz"
  binary_path="$install_dir/bluetuith"
  launcher_path="$HOME/.local/bin/bluetuith"
  tmp_dir="$TEMP_DIR/bluetuith.extract"

  run_cmd mkdir -p "$install_dir" "$HOME/.local/bin" "$tmp_dir"
  packages_info "installing Bluetuith from release archive: ${BLUETUITH_ARCHIVE_URL}"
  download_file "$BLUETUITH_ARCHIVE_URL" "$archive_path"
  run_cmd tar -xzf "$archive_path" -C "$tmp_dir"
  run_cmd install -m 0755 "$tmp_dir/bluetuith" "$binary_path"
  run_cmd ln -sfn "$binary_path" "$launcher_path"
  run_cmd rm -rf "$tmp_dir"
  record_file_action "$binary_path"
  record_file_action "$launcher_path -> $binary_path"
}

ensure_pnpm_installed() {
  if command -v pnpm >/dev/null 2>&1; then
    packages_info 'pnpm already installed'
    return 0
  fi

  if ! command -v npm >/dev/null 2>&1; then
    packages_warn 'npm not found, skipping pnpm fallback install'
    return 0
  fi

  packages_info 'installing pnpm via npm'
  record_direct_package_install 'npm:pnpm'
  run_as_root npm install -g pnpm
}

install_oh_my_zsh_if_needed() {
  local install_dir="$HOME/.oh-my-zsh"
  local clone_dir

  if [[ -d "$install_dir" ]]; then
    packages_info 'oh-my-zsh already installed'
    return 0
  fi

  if ! command -v zsh >/dev/null 2>&1 || ! command -v git >/dev/null 2>&1; then
    packages_warn 'zsh or git not found, skipping oh-my-zsh install'
    return 0
  fi

  clone_dir="$TEMP_DIR/oh-my-zsh"
  packages_info "installing oh-my-zsh from git: ${OH_MY_ZSH_REPO_URL} (${OH_MY_ZSH_REF})"

  run_cmd git init "$clone_dir"
  run_cmd git -C "$clone_dir" remote add origin "$OH_MY_ZSH_REPO_URL"
  run_cmd timeout --foreground "$GIT_TIMEOUT_SEC" git -C "$clone_dir" fetch --depth=1 origin "$OH_MY_ZSH_REF"
  run_cmd git -C "$clone_dir" checkout --detach FETCH_HEAD
  run_cmd git -C "$clone_dir" rev-parse --verify HEAD
  run_cmd mv "$clone_dir" "$install_dir"
  record_file_action "$install_dir"
}

ensure_zsh_dotfiles_sourcing() {
  local zshrc="$HOME/.zshrc"
  local marker_start='# >>> dotfiles-zsh >>>'
  local marker_end='# <<< dotfiles-zsh <<<'
  local block

  block="$(cat <<'EOT'
# >>> dotfiles-zsh >>>
[[ -f "$HOME/.config/zsh/aliases.zsh" ]] && source "$HOME/.config/zsh/aliases.zsh"
[[ -f "$HOME/.config/zsh/tools.zsh" ]] && source "$HOME/.config/zsh/tools.zsh"
# <<< dotfiles-zsh <<<
EOT
)"

  if is_dry_run; then
    [[ -f "$zshrc" ]] || run_cmd touch "$zshrc"
    packages_info "DRY_RUN: would ensure dotfiles zsh block in $zshrc"
    record_file_action "$zshrc"
    return 0
  fi

  [[ -f "$zshrc" ]] || touch "$zshrc"
  if grep -Fq "$marker_start" "$zshrc"; then
    awk -v start="$marker_start" -v end="$marker_end" '
      $0 == start {skip=1; next}
      $0 == end {skip=0; next}
      skip == 0 {print}
    ' "$zshrc" > "${zshrc}.tmp"
    mv "${zshrc}.tmp" "$zshrc"
  fi

  printf '\n%s\n' "$block" >> "$zshrc"
  record_file_action "$zshrc"
}

ensure_default_shell_zsh() {
  local zsh_path
  local passwd_shell

  zsh_path="$(command -v zsh || true)"
  if [[ -z "$zsh_path" ]]; then
    packages_warn 'zsh not found, cannot set default shell'
    return 0
  fi

  passwd_shell="$(getent passwd "$USER" | cut -d: -f7 || true)"
  if [[ "$passwd_shell" == "$zsh_path" ]]; then
    packages_info "default shell already set to $zsh_path"
    return 0
  fi

  packages_info "setting default shell to $zsh_path for user $USER"
  run_as_root usermod -s "$zsh_path" "$USER"
  record_shell_action "$USER -> $zsh_path"
}

check_video_group_membership() {
  if ! getent group video >/dev/null 2>&1; then
    packages_warn 'group "video" does not exist, skipping'
    return 0
  fi

  if id -nG "$USER" | grep -qw video; then
    packages_info "user $USER is already in group: video"
    return 0
  fi

  if [[ "${AUTO_ADD_VIDEO_GROUP:-1}" == '1' ]]; then
    packages_info "adding $USER to group video"
    record_group_modification "$USER -> video"
    run_as_root usermod -aG video "$USER"
  else
    packages_warn "user $USER is not in group video; set AUTO_ADD_VIDEO_GROUP=1 to add automatically"
  fi
}

check_docker_group_membership() {
  if ! getent group docker >/dev/null 2>&1; then
    packages_warn 'group "docker" does not exist yet, skipping'
    return 0
  fi

  if id -nG "$USER" | grep -qw docker; then
    packages_info "user $USER is already in group: docker"
    return 0
  fi

  packages_info "adding $USER to group docker"
  record_group_modification "$USER -> docker"
  run_as_root usermod -aG docker "$USER"
}

install_other_package_manager_apps() {
  packages_step 'Install Other Package-Manager Apps'
  ensure_handy_installed
  ensure_bluetuith_installed
  ensure_pnpm_installed
  install_oh_my_zsh_if_needed
}

run_post_install_tasks() {
  packages_step 'Run Post-Install Tasks'
  check_video_group_membership
  check_docker_group_membership
  ensure_zsh_dotfiles_sourcing
  ensure_default_shell_zsh
}
