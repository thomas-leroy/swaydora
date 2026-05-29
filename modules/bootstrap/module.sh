#!/usr/bin/env bash
set -euo pipefail

BOOTSTRAP_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_REPO_ROOT="$(cd "$BOOTSTRAP_MODULE_DIR/../.." && pwd)"

# shellcheck source=../../lib/path.sh
source "$BOOTSTRAP_REPO_ROOT/lib/path.sh"

BOOTSTRAP_MIN_FEDORA_VERSION="${BOOTSTRAP_MIN_FEDORA_VERSION:-43}"
BOOTSTRAP_MIN_DISK_KIB="${BOOTSTRAP_MIN_DISK_KIB:-8388608}"
BOOTSTRAP_MIN_RAM_KIB="${BOOTSTRAP_MIN_RAM_KIB:-4194304}"
BOOTSTRAP_CRITICAL_COMMANDS=(dnf curl tar gzip)
BOOTSTRAP_USER_DIRS=("$HOME/.config" "$HOME/.local/share/fonts" "$HOME/.cache/dotfiles")

bootstrap_display_path() {
  local path="$1"

  path_display_home "$path"
}

bootstrap_check_os() {
  local version

  if ! is_fedora; then
    log_warn "Unsupported distribution; Fedora ${BOOTSTRAP_MIN_FEDORA_VERSION}+ is recommended"
    return 0
  fi

  if ! version="$(fedora_version 2>/dev/null)"; then
    log_warn 'Fedora detected but version could not be read'
    return 0
  fi

  if [[ ! "$version" =~ ^[0-9]+$ || "$version" -lt "$BOOTSTRAP_MIN_FEDORA_VERSION" ]]; then
    log_warn "Unsupported Fedora version: $version; Fedora ${BOOTSTRAP_MIN_FEDORA_VERSION}+ is recommended"
    return 0
  fi

  log_ok "Fedora detected: $version"
}

bootstrap_check_disk() {
  local disk_available_kib

  if ! disk_available_kib="$(df -Pk "$HOME" 2>/dev/null | awk 'NR == 2 {print $4}')"; then
    log_warn "Could not measure free disk space under $HOME"
    return 0
  fi

  if [[ ! "$disk_available_kib" =~ ^[0-9]+$ || "$disk_available_kib" -le "$BOOTSTRAP_MIN_DISK_KIB" ]]; then
    log_warn "Low free disk space under $HOME: ${disk_available_kib:-unknown} KiB available"
    return 0
  fi

  log_ok "Disk space check passed: $disk_available_kib KiB available"
}

bootstrap_check_ram() {
  local ram_available_kib

  if ! ram_available_kib="$(awk '/^MemAvailable:/ {print $2; exit}' /proc/meminfo 2>/dev/null)"; then
    log_warn 'Could not measure available RAM'
    return 0
  fi

  if [[ ! "$ram_available_kib" =~ ^[0-9]+$ || "$ram_available_kib" -le "$BOOTSTRAP_MIN_RAM_KIB" ]]; then
    log_warn "Low available RAM: ${ram_available_kib:-unknown} KiB available"
    return 0
  fi

  log_ok "RAM check passed: $ram_available_kib KiB available"
}

bootstrap_check_commands() {
  local command_name

  for command_name in "${BOOTSTRAP_CRITICAL_COMMANDS[@]}"; do
    if command_exists "$command_name"; then
      log_ok "Bootstrap command available: $command_name"
    else
      log_warn "Missing recommended command for later setup steps: $command_name"
    fi
  done

  require_command mkdir
}

bootstrap_check() {
  log_info 'Checking bootstrap requirements'
  bootstrap_check_os
  bootstrap_check_disk
  bootstrap_check_ram
  bootstrap_check_commands
}

bootstrap_plan() {
  local dir display_dir

  for dir in "${BOOTSTRAP_USER_DIRS[@]}"; do
    display_dir="$(bootstrap_display_path "$dir")"
    if [[ -d "$dir" ]]; then
      log_ok "Directory already exists: $display_dir"
    else
      log_plan "Would create: $display_dir"
    fi
  done
}

bootstrap_apply() {
  local dir display_dir

  for dir in "${BOOTSTRAP_USER_DIRS[@]}"; do
    display_dir="$(bootstrap_display_path "$dir")"
    if [[ -d "$dir" ]]; then
      log_ok "Directory already exists: $display_dir"
      continue
    fi

    log_info "Creating directory: $display_dir"
    mkdir -p "$dir"
    log_ok "Directory created: $display_dir"
  done
}
