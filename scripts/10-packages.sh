#!/usr/bin/env bash
set -euo pipefail

# Optional flag: install virtualization stack when set to 1.
WITH_VIRT="${WITH_VIRT:-0}"
# Optional flag: auto-add current user to video group when missing (enabled by default).
AUTO_ADD_VIDEO_GROUP="${AUTO_ADD_VIDEO_GROUP:-1}"

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

main() {
  # Validate package manager commands.
  require_cmd dnf
  require_cmd rpm

  # Arrays used to keep install summary.
  TO_INSTALL=()
  SKIPPED=()

  # Resolve distro-specific package names.
  log 'resolving package variants for sway, terminal, swaylock, wallpaper, clipboard, and auto updates'
  local sway_pkg terminal_pkg swaylock_pkg wallpaper_pkg clipboard_pkg automatic_pkg notify_center_pkg
  sway_pkg="$(resolve_pkg swayfx sway)" || {
    printf '[packages] no sway package found (expected swayfx or sway)\n' >&2
    exit 1
  }
  terminal_pkg="$(resolve_pkg wezterm alacritty)" || {
    printf '[packages] no terminal package found (expected wezterm or alacritty)\n' >&2
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
  install_queued

  # Validate group access for brightness/video controls.
  check_video_group_membership

  # Print skipped package summary.
  if [[ "${#SKIPPED[@]}" -gt 0 ]]; then
    log 'some packages were skipped because unavailable in current repos:'
    printf '  - %s\n' "${SKIPPED[@]}"
  fi

  log 'done'
}

# Entrypoint.
main "$@"
