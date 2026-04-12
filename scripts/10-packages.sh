#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Optional flag: install virtualization stack when set to 1.
WITH_VIRT="${WITH_VIRT:-0}"
# Optional flag: print planned actions without changing the system.
DRY_RUN="${DRY_RUN:-0}"
# Optional flag: auto-add current user to video group when missing (enabled by default).
AUTO_ADD_VIDEO_GROUP="${AUTO_ADD_VIDEO_GROUP:-1}"
# Optional flag: fail if swayfx is unavailable (enabled by default).
REQUIRE_SWAYFX="${REQUIRE_SWAYFX:-1}"
# COPR repo used to install swayfx when not in default enabled repos.
SWAYFX_COPR="${SWAYFX_COPR:-swayfx/swayfx}"
# COPR repo used to install swayosd when not in default enabled repos.
SWAYOSD_COPR="${SWAYOSD_COPR:-erikreider/swayosd}"
# LibreWolf official repository and key.
LIBREWOLF_REPO_URL="${LIBREWOLF_REPO_URL:-https://repo.librewolf.net/librewolf.repo}"
LIBREWOLF_GPG_KEY_URL="${LIBREWOLF_GPG_KEY_URL:-https://repo.librewolf.net/pubkey.gpg}"
# Handy official RPM used when the package is not available in enabled repos.
HANDY_RPM_URL="${HANDY_RPM_URL:-https://github.com/cjpais/Handy/releases/download/v0.8.1/Handy-0.8.1-1.x86_64.rpm}"
# Obsidian official AppImage used when no distro package is available.
OBSIDIAN_APPIMAGE_URL="${OBSIDIAN_APPIMAGE_URL:-https://github.com/obsidianmd/obsidian-releases/releases/download/v1.10.6/Obsidian-1.10.6.AppImage}"
OBSIDIAN_APPIMAGE_SHA256="${OBSIDIAN_APPIMAGE_SHA256:-162d753076d0610e4dccfdccf391c13af5fcb557ba7574b77f0e90ac3c522b1c}"
# Insomnia official AppImage used when no distro package is available.
INSOMNIA_VERSION="${INSOMNIA_VERSION:-12.5.0}"
INSOMNIA_APPIMAGE_URL="${INSOMNIA_APPIMAGE_URL:-https://github.com/Kong/insomnia/releases/download/core@${INSOMNIA_VERSION}/Insomnia.Core-${INSOMNIA_VERSION}.AppImage}"
INSOMNIA_APPIMAGE_SHA256="${INSOMNIA_APPIMAGE_SHA256:-458373397f5644fa8f50c85b1bf01be08a76e629ae74d1a51d7d643cbcee43e5}"
# LocalSend official AppImage used when no distro package is available.
LOCALSEND_APPIMAGE_URL="${LOCALSEND_APPIMAGE_URL:-https://github.com/localsend/localsend/releases/download/v1.17.0/LocalSend-1.17.0-linux-x86-64.AppImage}"
LOCALSEND_APPIMAGE_SHA256="${LOCALSEND_APPIMAGE_SHA256:-c1a1e7bc7bb7eebdf6c365a30cef0d4ba3e6bb79961c3b94edf918920f8e36f0}"
# Bluetuith official release archive used when no distro package is available.
BLUETUITH_ARCHIVE_URL="${BLUETUITH_ARCHIVE_URL:-https://github.com/bluetuith-org/bluetuith/releases/download/v0.2.6/bluetuith_0.2.6_Linux_x86_64.tar.gz}"
# VS Code official repository file.
VSCODE_REPO_FILE='/etc/yum.repos.d/vscode.repo'
# Oh My Zsh official repository used for manual installation.
OH_MY_ZSH_REPO_URL="${OH_MY_ZSH_REPO_URL:-https://github.com/ohmyzsh/ohmyzsh.git}"
OH_MY_ZSH_REF="${OH_MY_ZSH_REF:-master}"
CURL_TIMEOUT_SEC="${CURL_TIMEOUT_SEC:-60}"
GIT_TIMEOUT_SEC="${GIT_TIMEOUT_SEC:-120}"
DNF_QUERY_TIMEOUT_SEC="${DNF_QUERY_TIMEOUT_SEC:-45}"

TEMP_DIR=''

source "$SCRIPT_DIR/lib/packages/common.sh"
source "$SCRIPT_DIR/lib/packages/dnf.sh"
source "$SCRIPT_DIR/lib/packages/flatpak.sh"
source "$SCRIPT_DIR/lib/packages/appimages.sh"
source "$SCRIPT_DIR/lib/packages/external.sh"

trap cleanup_temp_dir EXIT

resolve_package_variants() {
  local sway_pkg terminal_pkg swaylock_pkg wallpaper_pkg clipboard_pkg automatic_pkg notify_center_pkg swayosd_pkg
  local node_pkg npm_pkg docker_pkg docker_compose_pkg sysinfo_pkg fd_pkg launcher_pkg

  packages_step 'Resolve Repositories And Package Variants'
  enable_swayfx_copr_if_needed
  enable_swayosd_copr_if_needed
  enable_vscode_repo_if_needed
  enable_librewolf_repo_if_needed

  if ! pkg_is_available swayfx; then
    if is_dry_run; then
      packages_warn "DRY_RUN: swayfx not currently available; assuming COPR ${SWAYFX_COPR} will provide it"
      sway_pkg='swayfx'
    elif [[ "$REQUIRE_SWAYFX" == '1' ]]; then
      packages_error "swayfx package is required but still unavailable after COPR enable ($SWAYFX_COPR)"
      exit 1
    else
      packages_error 'swayfx package unavailable and REQUIRE_SWAYFX=0 is unsupported in this profile'
      exit 1
    fi
  else
    sway_pkg='swayfx'
  fi
  packages_info "using swayfx package: $sway_pkg"

  terminal_pkg="$(resolve_pkg kitty wezterm alacritty || true)"
  if [[ -z "$terminal_pkg" ]]; then
    if is_dry_run; then
      terminal_pkg='kitty'
      packages_warn 'DRY_RUN: no terminal package currently found; planning first candidate: kitty'
    else
      packages_error 'no terminal package found (expected kitty, wezterm, or alacritty)'
      exit 1
    fi
  fi
  packages_info "using terminal package: $terminal_pkg"

  if pkg_is_installed swaylock; then
    swaylock_pkg='swaylock'
  elif pkg_is_installed swaylock-effects; then
    swaylock_pkg='swaylock-effects'
  else
    swaylock_pkg="$(resolve_pkg swaylock swaylock-effects || true)"
  fi
  if [[ -z "$swaylock_pkg" ]]; then
    if is_dry_run; then
      swaylock_pkg='swaylock'
      packages_warn 'DRY_RUN: no swaylock package currently found; planning first candidate: swaylock'
    else
      packages_error 'no swaylock package found (expected swaylock or swaylock-effects)'
      exit 1
    fi
  fi

  wallpaper_pkg="$(resolve_pkg swww swaybg || true)"
  if [[ -z "$wallpaper_pkg" ]]; then
    if is_dry_run; then
      wallpaper_pkg='swww'
      packages_warn 'DRY_RUN: no wallpaper package currently found; planning first candidate: swww'
    else
      packages_error 'no wallpaper package found (expected swww or swaybg)'
      exit 1
    fi
  fi

  clipboard_pkg="$(resolve_pkg cliphist clipman || true)"
  launcher_pkg="$(resolve_pkg fuzzel wofi rofi-wayland rofi || true)"
  automatic_pkg="$(resolve_pkg dnf5-plugin-automatic dnf-automatic || true)"
  notify_center_pkg="$(resolve_pkg swaync SwayNotificationCenter swaynotificationcenter || true)"
  swayosd_pkg="$(resolve_pkg swayosd || true)"
  node_pkg="$(resolve_pkg nodejs || true)"
  npm_pkg="$(resolve_pkg npm || true)"
  docker_pkg="$(resolve_pkg docker moby-engine docker-ce || true)"
  docker_compose_pkg="$(resolve_pkg docker-compose docker-compose-plugin || true)"
  sysinfo_pkg="$(resolve_pkg fastfetch neofetch || true)"
  fd_pkg="$(resolve_pkg fd fd-find || true)"

  RESOLVED_SWAY_PKG="$sway_pkg"
  RESOLVED_TERMINAL_PKG="$terminal_pkg"
  RESOLVED_SWAYLOCK_PKG="$swaylock_pkg"
  RESOLVED_WALLPAPER_PKG="$wallpaper_pkg"
  RESOLVED_CLIPBOARD_PKG="$clipboard_pkg"
  RESOLVED_LAUNCHER_PKG="$launcher_pkg"
  RESOLVED_AUTOMATIC_PKG="$automatic_pkg"
  RESOLVED_NOTIFY_CENTER_PKG="$notify_center_pkg"
  RESOLVED_SWAYOSD_PKG="$swayosd_pkg"
  RESOLVED_NODE_PKG="$node_pkg"
  RESOLVED_NPM_PKG="$npm_pkg"
  RESOLVED_DOCKER_PKG="$docker_pkg"
  RESOLVED_DOCKER_COMPOSE_PKG="$docker_compose_pkg"
  RESOLVED_SYSINFO_PKG="$sysinfo_pkg"
  RESOLVED_FD_PKG="$fd_pkg"
}

queue_dnf_packages() {
  packages_step 'Queue DNF Packages'

  queue_pkg "$RESOLVED_SWAY_PKG"
  queue_pkg "$RESOLVED_TERMINAL_PKG"
  queue_pkg waybar
  [[ -n "$RESOLVED_LAUNCHER_PKG" ]] && queue_pkg "$RESOLVED_LAUNCHER_PKG" || packages_warn 'launcher package not found (expected fuzzel/wofi/rofi)'
  queue_pkg mako
  [[ -n "$RESOLVED_NOTIFY_CENTER_PKG" ]] && queue_pkg "$RESOLVED_NOTIFY_CENTER_PKG" || packages_warn 'notification center package not found (expected swaync or swaynotificationcenter)'
  [[ -n "$RESOLVED_SWAYOSD_PKG" ]] && queue_pkg "$RESOLVED_SWAYOSD_PKG" || packages_warn 'swayosd package not found'
  queue_pkg wlogout
  queue_pkg brightnessctl
  queue_pkg swayidle
  queue_pkg "$RESOLVED_SWAYLOCK_PKG"
  queue_pkg "$RESOLVED_WALLPAPER_PKG"
  queue_pkg grim
  queue_pkg slurp
  queue_pkg hyprpicker
  queue_pkg jq
  queue_pkg xdg-desktop-portal
  queue_pkg xdg-desktop-portal-gtk
  queue_pkg xdg-desktop-portal-wlr
  queue_pkg bluez
  queue_pkg bluez-tools
  queue_pkg wl-clipboard
  queue_pkg wtype
  queue_pkg gnome-keyring
  queue_pkg seahorse
  queue_pkg celluloid
  [[ -n "$RESOLVED_CLIPBOARD_PKG" ]] && queue_pkg "$RESOLVED_CLIPBOARD_PKG" || packages_warn 'clipboard history package not found (expected cliphist or clipman)'
  queue_pkg curl
  queue_pkg unzip

  queue_pkg nano
  queue_pkg openssh-server
  queue_pkg btop
  queue_pkg bat
  queue_pkg grep
  queue_pkg gawk
  queue_pkg sed
  queue_pkg gcc
  queue_pkg python3
  queue_pkg git
  queue_pkg git-extras
  queue_pkg tig
  queue_pkg ripgrep
  queue_pkg fzf
  queue_pkg duf
  queue_pkg zoxide
  queue_pkg atuin
  [[ -n "$RESOLVED_SYSINFO_PKG" ]] && queue_pkg "$RESOLVED_SYSINFO_PKG" || packages_warn 'system info package not found (expected fastfetch or neofetch)'
  [[ -n "$RESOLVED_FD_PKG" ]] && queue_pkg "$RESOLVED_FD_PKG" || packages_warn 'fd package not found (expected fd or fd-find)'
  queue_pkg zsh
  [[ -n "$RESOLVED_NODE_PKG" ]] && queue_pkg "$RESOLVED_NODE_PKG" || packages_warn 'nodejs package not found'
  [[ -n "$RESOLVED_NPM_PKG" ]] && queue_pkg "$RESOLVED_NPM_PKG" || packages_warn 'npm package not found as standalone package'
  pkg_is_available pnpm && queue_pkg pnpm || true
  [[ -n "$RESOLVED_DOCKER_PKG" ]] && queue_pkg "$RESOLVED_DOCKER_PKG" || packages_warn 'docker engine package not found (expected docker, moby-engine, or docker-ce)'
  [[ -n "$RESOLVED_DOCKER_COMPOSE_PKG" ]] && queue_pkg "$RESOLVED_DOCKER_COMPOSE_PKG" || packages_warn 'docker compose package not found (expected docker-compose or docker-compose-plugin)'
  queue_pkg librewolf
  queue_pkg code
  queue_pkg thunderbird

  queue_pkg pipewire
  queue_pkg wireplumber
  queue_pkg pavucontrol

  queue_pkg NetworkManager-tui
  queue_pkg udisks2
  queue_pkg udiskie
  queue_pkg v4l-utils
  queue_pkg guvcview

  queue_pkg plasma-discover
  [[ -n "$RESOLVED_AUTOMATIC_PKG" ]] && queue_pkg "$RESOLVED_AUTOMATIC_PKG" || packages_warn 'automatic updates package not found (expected dnf5-plugin-automatic or dnf-automatic)'
  queue_pkg fwupd
  queue_pkg firewalld

  if [[ "$WITH_VIRT" == '1' ]]; then
    queue_pkg virt-manager
    queue_pkg libvirt
    queue_pkg qemu-kvm
  else
    packages_info 'virtualization packages skipped (set WITH_VIRT=1 to enable)'
  fi
}

print_summary() {
  if [[ "${#SKIPPED[@]}" -gt 0 ]]; then
    packages_warn 'some packages were skipped because unavailable in current repos:'
    printf '  - %s\n' "${SKIPPED[@]}"
  fi

  printf '\n[packages] Summary\n'
  printf '  packages handled: %s\n' "$(( ${#TO_INSTALL[@]} + ${#DIRECT_PACKAGE_INSTALLS[@]} ))"
  printf '  group modifications: %s\n' "${#GROUP_MODIFICATIONS[@]}"
  printf '  repo/service actions: %s\n' "${#SERVICE_ACTIONS[@]}"
  printf '  files written/linked: %s\n' "${#FILE_ACTIONS[@]}"
  printf '  shell modifications: %s\n' "${#SHELL_ACTIONS[@]}"
  printf '  packages skipped: %s\n' "${#SKIPPED[@]}"
}

main() {
  require_cmd rpm
  require_cmd timeout

  TO_INSTALL=()
  SKIPPED=()
  DIRECT_PACKAGE_INSTALLS=()
  GROUP_MODIFICATIONS=()
  FILE_ACTIONS=()
  SERVICE_ACTIONS=()
  SHELL_ACTIONS=()

  init_temp_dir
  stop_blocking_package_managers
  resolve_package_variants
  queue_dnf_packages
  ensure_swayfx_installed_without_conflict
  install_queued
  install_flatpak_apps
  install_other_package_manager_apps
  install_appimage_apps
  run_post_install_tasks
  print_summary
}

main "$@"
