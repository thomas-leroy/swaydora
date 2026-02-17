#!/usr/bin/env bash
set -euo pipefail

# Nerd Fonts release used by fallback download path.
NF_VERSION="${NF_VERSION:-3.3.0}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/fonts"
FONT_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerd"

# Print consistent log messages for this script.
log() {
  printf '[fonts] %s\n' "$*"
}

# Run privileged commands with sudo when not root.
run_as_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

# Return success when package is available or already installed.
pkg_is_available() {
  dnf -q list --available "$1" >/dev/null 2>&1 || dnf -q list --installed "$1" >/dev/null 2>&1
}

# Return success when package is already installed.
pkg_is_installed() {
  rpm -q "$1" >/dev/null 2>&1
}

# Try to install one package if possible.
try_install_pkg() {
  local pkg="$1"
  if pkg_is_installed "$pkg"; then
    log "already installed: $pkg"
    return 0
  fi
  if pkg_is_available "$pkg"; then
    log "installing package: $pkg"
    run_as_root dnf install -y "$pkg"
    return 0
  fi
  return 1
}

# Download JetBrainsMono Nerd Font zip and verify checksum before extraction.
download_nerd_font() {
  mkdir -p "$CACHE_DIR" "$FONT_DIR"
  local zip="$CACHE_DIR/JetBrainsMono.zip"
  local sums="$CACHE_DIR/SHA256SUMS"
  local base_url="https://github.com/ryanoasis/nerd-fonts/releases/download/v${NF_VERSION}"

  log "downloading Nerd Fonts JetBrainsMono v${NF_VERSION}"
  curl -fsSL -o "$zip" "$base_url/JetBrainsMono.zip"
  curl -fsSL -o "$sums" "$base_url/SHA256SUMS"

  # Read expected checksum for JetBrainsMono.zip.
  local expected actual
  expected="$(grep -E '[[:xdigit:]]+[[:space:]]+JetBrainsMono\.zip$' "$sums" | awk '{print $1; exit}')"
  if [[ -z "$expected" ]]; then
    printf '[fonts] checksum entry not found for JetBrainsMono.zip\n' >&2
    return 1
  fi

  # Compare expected checksum with downloaded file checksum.
  actual="$(sha256sum "$zip" | awk '{print $1}')"
  if [[ "$expected" != "$actual" ]]; then
    printf '[fonts] checksum mismatch for JetBrainsMono.zip\n' >&2
    return 1
  fi

  # Extract/refresh font files in local font directory.
  unzip -oq "$zip" -d "$FONT_DIR"
}

main() {
  # Require Fedora package manager.
  command -v dnf >/dev/null 2>&1 || {
    printf '[fonts] dnf not found\n' >&2
    exit 1
  }

  # Try packaged fonts first.
  local has_nerd_pkg=0
  try_install_pkg jetbrains-mono-fonts || true
  if try_install_pkg nerd-fonts-jetbrains-mono; then
    has_nerd_pkg=1
  elif try_install_pkg jetbrainsmono-nerd-fonts; then
    has_nerd_pkg=1
  fi

  # If no nerd-font package exists, install from official release zip.
  if [[ "$has_nerd_pkg" -eq 0 ]]; then
    command -v curl >/dev/null 2>&1 || {
      printf '[fonts] curl is required for Nerd Fonts fallback download\n' >&2
      exit 1
    }
    command -v unzip >/dev/null 2>&1 || {
      printf '[fonts] unzip is required for Nerd Fonts fallback download\n' >&2
      exit 1
    }
    download_nerd_font
  fi

  # Refresh fontconfig cache.
  fc-cache -f
  log 'font cache refreshed'
}

# Entrypoint.
main "$@"
