#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/logging.sh"
setup_logger bootstrap

MIN_FEDORA_VERSION="${MIN_FEDORA_VERSION:-43}"
MIN_DISK_KIB="${MIN_DISK_KIB:-8388608}"
MIN_RAM_KIB="${MIN_RAM_KIB:-4194304}"

# Ensure a required command exists before running main steps.
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    log_error "missing required command: $1"
    exit 1
  }
}

report_system_requirements() {
  local fedora_id='unknown'
  local fedora_version='unknown'
  local disk_available_kib='unknown'
  local ram_available_kib='unknown'
  local cmd
  local -a critical_commands
  local issues=0

  log 'checking system requirements (informational only)'

  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    fedora_id="${ID:-unknown}"
    fedora_version="${VERSION_ID:-unknown}"
    if [[ "$fedora_id" != 'fedora' ]]; then
      log_warn "unsupported distribution: ${fedora_id}; this setup is primarily intended for Fedora ${MIN_FEDORA_VERSION}+"
      ((issues += 1))
    elif [[ ! "$fedora_version" =~ ^[0-9]+$ || "$fedora_version" -lt "$MIN_FEDORA_VERSION" ]]; then
      log_warn "unsupported Fedora version: ${fedora_version}; Fedora ${MIN_FEDORA_VERSION}+ is recommended"
      ((issues += 1))
    fi
  else
    log_warn '/etc/os-release not found; cannot verify Fedora version'
    ((issues += 1))
  fi

  if disk_available_kib="$(df -Pk "$HOME" 2>/dev/null | awk 'NR == 2 {print $4}')"; then
    if [[ ! "$disk_available_kib" =~ ^[0-9]+$ || "$disk_available_kib" -le "$MIN_DISK_KIB" ]]; then
      log_warn "low free disk space under $HOME: ${disk_available_kib:-unknown} KiB available; more than $MIN_DISK_KIB KiB is recommended"
      ((issues += 1))
    fi
  else
    log_warn "could not measure free disk space under $HOME"
    ((issues += 1))
  fi

  if ram_available_kib="$(awk '/^MemAvailable:/ {print $2; exit}' /proc/meminfo 2>/dev/null)"; then
    if [[ ! "$ram_available_kib" =~ ^[0-9]+$ || "$ram_available_kib" -le "$MIN_RAM_KIB" ]]; then
      log_warn "low available RAM: ${ram_available_kib:-unknown} KiB available; more than $MIN_RAM_KIB KiB is recommended"
      ((issues += 1))
    fi
  else
    log_warn 'could not measure available RAM'
    ((issues += 1))
  fi

  critical_commands=(dnf curl tar gzip)
  for cmd in "${critical_commands[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      log_warn "missing recommended command for later setup steps: $cmd"
      ((issues += 1))
    fi
  done

  if (( issues == 0 )); then
    log_success "system requirements look good: Fedora $fedora_version, disk/RAM thresholds met, critical commands present"
  else
    log_warn "system requirement check found $issues issue(s); continuing anyway"
  fi
}

main() {
  report_system_requirements

  # Validate dependencies used by this script.
  require_cmd mkdir

  # Create base directories used by setup/runtime scripts.
  local -a created_dirs
  created_dirs=("$HOME/.config" "$HOME/.local/share/fonts" "$HOME/.cache/dotfiles")

  log 'creating user config and cache directories'
  mkdir -p "${created_dirs[@]}"

  log 'summary:'
  log "directories ensured: ${#created_dirs[@]}"
  printf '  - %s\n' "${created_dirs[@]}"
  log_success 'done'
}

# Entrypoint.
main "$@"
