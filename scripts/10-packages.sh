#!/usr/bin/env bash
set -euo pipefail

# Optional flag: install virtualization stack when set to 1.
WITH_VIRT="${WITH_VIRT:-0}"
# Optional flag: auto-add current user to video group when missing (enabled by default).
AUTO_ADD_VIDEO_GROUP="${AUTO_ADD_VIDEO_GROUP:-1}"
# Optional flag: fail if swayfx is unavailable (enabled by default).
REQUIRE_SWAYFX="${REQUIRE_SWAYFX:-1}"
# COPR repo used to install swayfx when not in default enabled repos.
SWAYFX_COPR="${SWAYFX_COPR:-swayfx/swayfx}"
# VS Code official repository file.
VSCODE_REPO_FILE='/etc/yum.repos.d/vscode.repo'

# Print consistent log messages for this script.
log() {
  printf '[packages] %s\n' "$*"
}

# Run privileged commands with sudo when not root.
run_as_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

# Ensure required command is available.
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf '[packages] missing required command: %s\n' "$1" >&2
    exit 1
  }
}

# Return success when a package is already installed.
pkg_is_installed() {
  rpm -q "$1" >/dev/null 2>&1
}

# Return success when a package exists in enabled repos or is already installed.
pkg_is_available() {
  local pkg="$1"
  local out

  # Check exact package match in available packages.
  out="$(dnf -q list --available "$pkg" 2>/dev/null || true)"
  if awk -v p="$pkg" '$1 ~ ("^" p "(\\.|$)") {found=1} END{exit(found ? 0 : 1)}' <<<"$out"; then
    return 0
  fi

  # Check exact package match in installed packages.
  out="$(dnf -q list --installed "$pkg" 2>/dev/null || true)"
  awk -v p="$pkg" '$1 ~ ("^" p "(\\.|$)") {found=1} END{exit(found ? 0 : 1)}' <<<"$out"
}

# Pick the first package name variant that exists.
resolve_pkg() {
  local candidate
  for candidate in "$@"; do
    if pkg_is_available "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

# Queue an installable package, or mark it as skipped.
queue_pkg() {
  local pkg="$1"
  if pkg_is_installed "$pkg"; then
    log "already installed: $pkg"
    return 0
  fi
  if pkg_is_available "$pkg"; then
    TO_INSTALL+=("$pkg")
    log "queued: $pkg"
  else
    SKIPPED+=("$pkg")
    log "not available in enabled repos: $pkg"
  fi
}

# Install all queued packages in one dnf transaction.
install_queued() {
  if [[ "${#TO_INSTALL[@]}" -eq 0 ]]; then
    log 'nothing to install'
    return 0
  fi
  log "installing ${#TO_INSTALL[@]} package(s)"
  run_as_root dnf install -y "${TO_INSTALL[@]}"
}

# Replace plain sway with swayfx when sway is already installed.
ensure_swayfx_installed_without_conflict() {
  if pkg_is_installed swayfx; then
    return 0
  fi

  if pkg_is_installed sway; then
    log 'detected installed sway package, swapping to swayfx'
    run_as_root dnf swap -y --allowerasing sway swayfx
  fi
}

# Enable official VS Code repository when `code` package is missing.
enable_vscode_repo_if_needed() {
  if pkg_is_available code || pkg_is_installed code; then
    return 0
  fi

  log 'enabling Visual Studio Code repository'
  run_as_root rpm --import https://packages.microsoft.com/keys/microsoft.asc
  run_as_root tee "$VSCODE_REPO_FILE" >/dev/null <<'EOT'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOT
}

# Ensure `dnf copr` command is available.
ensure_copr_command() {
  if dnf -q copr list >/dev/null 2>&1; then
    return 0
  fi

  # Install plugin package when needed.
  if ! pkg_is_installed dnf-plugins-core && pkg_is_available dnf-plugins-core; then
    log 'installing dnf-plugins-core to enable COPR command support'
    run_as_root dnf install -y dnf-plugins-core
  fi

  dnf -q copr list >/dev/null 2>&1 || {
    printf '[packages] dnf copr command is not available on this system\n' >&2
    exit 1
  }
}

# Enable swayfx COPR when swayfx package is not available yet.
enable_swayfx_copr_if_needed() {
  if pkg_is_available swayfx; then
    return 0
  fi

  log "swayfx not found in current repos, enabling COPR: ${SWAYFX_COPR}"
  ensure_copr_command
  run_as_root dnf -y copr enable "${SWAYFX_COPR}"
}

# Verify whether current user can access brightness/video related devices.
check_video_group_membership() {
  if ! getent group video >/dev/null 2>&1; then
    log 'group "video" does not exist on this system, skipping group check'
    return 0
  fi

  if id -nG "$USER" | grep -qw video; then
    log "user $USER is already in group: video"
    return 0
  fi

  if [[ "$AUTO_ADD_VIDEO_GROUP" == '1' ]]; then
    log "adding $USER to group video (AUTO_ADD_VIDEO_GROUP=1)"
    run_as_root usermod -aG video "$USER"
    log 'group updated; logout/login is required to apply new group membership'
  else
    log "user $USER is not in group video; set AUTO_ADD_VIDEO_GROUP=1 to add automatically"
  fi
}

# Ensure current user can use Docker without sudo.
check_docker_group_membership() {
  if ! getent group docker >/dev/null 2>&1; then
    log 'group "docker" does not exist yet, skipping docker group update'
    return 0
  fi

  if id -nG "$USER" | grep -qw docker; then
    log "user $USER is already in group: docker"
    return 0
  fi

  log "adding $USER to group docker"
  run_as_root usermod -aG docker "$USER"
  log 'docker group updated; logout/login is required to apply new group membership'
}

# Install pnpm globally when distro package is unavailable.
ensure_pnpm_installed() {
  if command -v pnpm >/dev/null 2>&1; then
    log 'pnpm already installed'
    return 0
  fi

  if ! command -v npm >/dev/null 2>&1; then
    log 'npm not found, skipping pnpm fallback install'
    return 0
  fi

  log 'installing pnpm globally via npm fallback'
  run_as_root npm install -g pnpm
}

# Install oh-my-zsh for the current user in unattended mode.
install_oh_my_zsh_if_needed() {
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    log 'oh-my-zsh already installed'
    return 0
  fi

  if ! command -v zsh >/dev/null 2>&1; then
    log 'zsh not found, skipping oh-my-zsh install'
    return 0
  fi

  if ! command -v curl >/dev/null 2>&1; then
    log 'curl not found, skipping oh-my-zsh install'
    return 0
  fi

  log 'installing oh-my-zsh in unattended mode'
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

# Ensure zsh loads dotfiles aliases/tooling from ~/.config/zsh.
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
  log 'ensured ~/.zshrc sources ~/.config/zsh aliases and tools'
}

# Ensure zsh is the default login shell for the current user.
ensure_default_shell_zsh() {
  local zsh_path
  zsh_path="$(command -v zsh || true)"
  if [[ -z "$zsh_path" ]]; then
    log 'zsh not found, cannot set default shell'
    return 0
  fi

  local passwd_shell
  passwd_shell="$(getent passwd "$USER" | cut -d: -f7 || true)"
  if [[ "$passwd_shell" == "$zsh_path" ]]; then
    log "default shell already set to $zsh_path"
    return 0
  fi

  log "setting default shell to $zsh_path for user $USER (current: ${passwd_shell:-unknown})"

  # Prefer chsh for user account shell change, fallback to usermod when needed.
  if command -v chsh >/dev/null 2>&1; then
    if chsh -s "$zsh_path" "$USER" >/dev/null 2>&1; then
      log 'default shell changed using chsh'
      log 'default shell updated; logout/login is required to apply it everywhere'
      return 0
    fi
  fi

  run_as_root usermod -s "$zsh_path" "$USER"
  log 'default shell updated; logout/login is required to apply it everywhere'
}

main() {
  # Validate package manager commands.
  require_cmd dnf
  require_cmd rpm

  # Arrays used to keep install summary.
  TO_INSTALL=()
  SKIPPED=()

  # Resolve distro-specific package names.
  log 'resolving package variants for swayfx, terminal, swaylock, wallpaper, clipboard, updates, and dev stack'
  local sway_pkg terminal_pkg swaylock_pkg wallpaper_pkg clipboard_pkg automatic_pkg notify_center_pkg
  local node_pkg npm_pkg docker_pkg docker_compose_pkg sysinfo_pkg fd_pkg
  enable_swayfx_copr_if_needed
  enable_vscode_repo_if_needed
  if ! pkg_is_available swayfx; then
    if [[ "$REQUIRE_SWAYFX" == '1' ]]; then
      printf '[packages] swayfx package is required but still unavailable after COPR enable (%s)\n' "$SWAYFX_COPR" >&2
      exit 1
    fi
    printf '[packages] swayfx package unavailable and REQUIRE_SWAYFX=0 is unsupported in this profile\n' >&2
    exit 1
  fi
  sway_pkg='swayfx'
  log 'using swayfx package'
  terminal_pkg="$(resolve_pkg kitty wezterm alacritty)" || {
    printf '[packages] no terminal package found (expected kitty, wezterm, or alacritty)\n' >&2
    exit 1
  }
  swaylock_pkg="$(resolve_pkg swaylock-effects swaylock)" || {
    printf '[packages] no swaylock package found (expected swaylock-effects or swaylock)\n' >&2
    exit 1
  }
  wallpaper_pkg="$(resolve_pkg swww swaybg)" || {
    printf '[packages] no wallpaper package found (expected swww or swaybg)\n' >&2
    exit 1
  }
  clipboard_pkg="$(resolve_pkg cliphist clipman || true)"
  automatic_pkg="$(resolve_pkg dnf5-plugin-automatic dnf-automatic || true)"
  notify_center_pkg="$(resolve_pkg swaync SwayNotificationCenter swaynotificationcenter || true)"
  node_pkg="$(resolve_pkg nodejs || true)"
  npm_pkg="$(resolve_pkg npm || true)"
  docker_pkg="$(resolve_pkg docker moby-engine docker-ce || true)"
  docker_compose_pkg="$(resolve_pkg docker-compose docker-compose-plugin || true)"
  sysinfo_pkg="$(resolve_pkg fastfetch neofetch || true)"
  fd_pkg="$(resolve_pkg fd fd-find || true)"

  # Core Wayland desktop stack.
  log 'core WM packages'
  queue_pkg "$sway_pkg"
  queue_pkg "$terminal_pkg"
  queue_pkg waybar
  queue_pkg fuzzel
  queue_pkg mako
  if [[ -n "$notify_center_pkg" ]]; then
    queue_pkg "$notify_center_pkg"
  else
    log 'notification center package not found (expected swaync or swaynotificationcenter), continuing without it'
  fi
  queue_pkg wlogout
  queue_pkg brightnessctl
  queue_pkg swayidle
  queue_pkg "$swaylock_pkg"
  queue_pkg "$wallpaper_pkg"
  queue_pkg grim
  queue_pkg slurp
  queue_pkg wl-clipboard
  if [[ -n "$clipboard_pkg" ]]; then
    queue_pkg "$clipboard_pkg"
  else
    log 'clipboard history package not found (expected cliphist or clipman), continuing without it'
  fi
  queue_pkg curl
  queue_pkg unzip

  # Developer baseline packages.
  log 'developer baseline packages'
  queue_pkg nano
  queue_pkg openssh-server
  queue_pkg btop
  queue_pkg bat
  queue_pkg grep
  queue_pkg gawk
  queue_pkg sed
  queue_pkg gcc
  queue_pkg python3
  queue_pkg python3-pip
  queue_pkg git-extras
  queue_pkg tig
  queue_pkg ripgrep
  queue_pkg fzf
  queue_pkg duf
  queue_pkg zoxide
  queue_pkg atuin
  if [[ -n "$sysinfo_pkg" ]]; then
    queue_pkg "$sysinfo_pkg"
  else
    log 'system info package not found (expected fastfetch or neofetch), continuing without it'
  fi
  if [[ -n "$fd_pkg" ]]; then
    queue_pkg "$fd_pkg"
  else
    log 'fd package not found (expected fd or fd-find), continuing without it'
  fi
  queue_pkg zsh
  if [[ -n "$node_pkg" ]]; then
    queue_pkg "$node_pkg"
  else
    log 'nodejs package not found in enabled repos'
  fi
  if [[ -n "$npm_pkg" ]]; then
    queue_pkg "$npm_pkg"
  else
    log 'npm package not found as standalone package (will rely on nodejs-provided npm if available)'
  fi
  if pkg_is_available pnpm; then
    queue_pkg pnpm
  fi
  if [[ -n "$docker_pkg" ]]; then
    queue_pkg "$docker_pkg"
  else
    log 'docker engine package not found (expected docker, moby-engine, or docker-ce)'
  fi
  if [[ -n "$docker_compose_pkg" ]]; then
    queue_pkg "$docker_compose_pkg"
  else
    log 'docker compose package not found (expected docker-compose or docker-compose-plugin)'
  fi
  queue_pkg code

  # Audio stack and fallback UI mixer.
  log 'audio packages'
  queue_pkg pipewire
  queue_pkg wireplumber
  queue_pkg pavucontrol

  # External disk management tools.
  log 'external disk packages'
  queue_pkg udisks2
  queue_pkg udiskie

  # Webcam tooling.
  log 'webcam packages'
  queue_pkg v4l-utils
  queue_pkg guvcview

  # Security and update automation tools.
  log 'updates and security packages'
  if [[ -n "$automatic_pkg" ]]; then
    queue_pkg "$automatic_pkg"
  else
    log 'automatic updates package not found (expected dnf5-plugin-automatic or dnf-automatic)'
  fi
  queue_pkg fwupd
  queue_pkg firewalld

  # Optional virtualization packages.
  if [[ "$WITH_VIRT" == '1' ]]; then
    log 'virtualization packages enabled by WITH_VIRT=1'
    queue_pkg virt-manager
    queue_pkg libvirt
    queue_pkg qemu-kvm
  else
    log 'virtualization packages skipped (set WITH_VIRT=1 to enable)'
  fi

  # Apply installation.
  ensure_swayfx_installed_without_conflict
  install_queued

  # Validate group access for brightness/video controls.
  check_video_group_membership
  check_docker_group_membership
  ensure_pnpm_installed
  install_oh_my_zsh_if_needed
  ensure_zsh_dotfiles_sourcing
  ensure_default_shell_zsh

  # Print skipped package summary.
  if [[ "${#SKIPPED[@]}" -gt 0 ]]; then
    log 'some packages were skipped because unavailable in current repos:'
    printf '  - %s\n' "${SKIPPED[@]}"
  fi

  log 'done'
}

# Entrypoint.
main "$@"
