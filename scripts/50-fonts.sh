#!/usr/bin/env bash
set -euo pipefail

# Nerd Fonts release used by fallback download path.
NF_VERSION="${NF_VERSION:-3.4.0}"
NF_FALLBACK_VERSIONS="${NF_FALLBACK_VERSIONS:-3.2.1}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/fonts"
FONT_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerd"
REQUIRED_CP_HEX="${REQUIRED_CP_HEX:-e7d9}"

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
  local -a versions sum_files
  local version base_url sum_file expected actual downloaded verified

  versions=("latest")
  versions+=("$NF_VERSION")
  # shellcheck disable=SC2206
  versions+=($NF_FALLBACK_VERSIONS)
  sum_files=("SHA256SUMS" "sha256sum.txt" "SHA-256.txt")
  downloaded=0
  verified=0

  for version in "${versions[@]}"; do
    if [[ "$version" == "latest" ]]; then
      base_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download"
      log 'downloading Nerd Fonts JetBrainsMono (latest release)'
    else
      base_url="https://github.com/ryanoasis/nerd-fonts/releases/download/v${version}"
      log "downloading Nerd Fonts JetBrainsMono v${version}"
    fi
    if ! curl -fsSL -o "$zip" "$base_url/JetBrainsMono.zip"; then
      log "release asset not found for ${version}, trying next"
      continue
    fi
    downloaded=1

    for sum_file in "${sum_files[@]}"; do
      if ! curl -fsSL -o "$sums" "$base_url/$sum_file" 2>/dev/null; then
        continue
      fi

      expected="$(awk '$2 ~ /JetBrainsMono\.zip$/ {print $1; exit}' "$sums")"
      if [[ -z "$expected" ]]; then
        continue
      fi

      actual="$(sha256sum "$zip" | awk '{print $1}')"
      if [[ "$expected" == "$actual" ]]; then
        verified=1
        break
      fi
      printf '[fonts] checksum mismatch for JetBrainsMono.zip (v%s)\n' "$version" >&2
      return 1
    done

    if [[ "$verified" -eq 0 ]]; then
      log "checksum file not found/usable for ${version}; continuing without checksum verification"
    fi
    break
  done

  if [[ "$downloaded" -eq 0 ]]; then
    printf '[fonts] unable to download JetBrainsMono.zip from configured versions (%s %s)\n' "$NF_VERSION" "$NF_FALLBACK_VERSIONS" >&2
    return 1
  fi

  unzip -oq "$zip" -d "$FONT_DIR"
}

# Return success when a font file contains the given Unicode codepoint.
font_has_codepoint() {
  local font_file="$1"
  local cp_hex="${2,,}"
  local cp_dec=$((16#$cp_hex))
  local token start_hex end_hex

  while IFS= read -r token; do
    token="${token,,}"
    [[ -n "$token" ]] || continue

    if [[ "$token" == *-* ]]; then
      start_hex="${token%-*}"
      end_hex="${token#*-}"
      [[ "$start_hex" =~ ^[0-9a-f]+$ && "$end_hex" =~ ^[0-9a-f]+$ ]] || continue
      if (( 16#$start_hex <= cp_dec && cp_dec <= 16#$end_hex )); then
        return 0
      fi
      continue
    fi

    [[ "$token" == "$cp_hex" ]] && return 0
  done < <(fc-query --format '%{charset}\n' "$font_file" | tr ' ' '\n')

  return 1
}

# Return success when fontconfig-resolved JetBrainsMono Nerd Font has required glyph.
resolved_font_has_required_glyph() {
  local matched_font
  matched_font="$(fc-match -f '%{file}\n' 'JetBrainsMono Nerd Font' 2>/dev/null || true)"
  [[ -n "$matched_font" && -f "$matched_font" ]] || return 1
  font_has_codepoint "$matched_font" "$REQUIRED_CP_HEX"
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

  # Some distro-packaged/legacy Nerd Fonts miss newer glyphs (for example e7d9).
  # Force local fallback install when resolved font lacks required codepoint.
  if ! resolved_font_has_required_glyph; then
    log "resolved JetBrainsMono Nerd Font misses U+${REQUIRED_CP_HEX^^}; installing fallback Nerd Fonts zip"
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
