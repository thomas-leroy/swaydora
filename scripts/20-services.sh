#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/logging.sh"
setup_logger services
ENABLED_UNITS=()
SKIPPED_UNITS=()

# Run privileged commands with sudo when not root.
run_as_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

# Check whether a systemd unit file exists on this machine.
unit_exists() {
  systemctl list-unit-files "$1" --all --no-legend 2>/dev/null | awk '{print $1}' | grep -Fxq "$1"
}

# Enable and start a unit only when it is present.
enable_now() {
  local unit="$1"
  if unit_exists "$unit"; then
    log "enabling and starting: $unit"
    run_as_root systemctl enable --now "$unit"
    ENABLED_UNITS+=("$unit")
  else
    log_warn "unit not found, skipping: $unit"
    SKIPPED_UNITS+=("$unit")
  fi
}

main() {
  # Enable required update/security timers and firewall service.
  enable_now dnf-automatic.timer
  enable_now dnf5-automatic.timer
  enable_now firewalld.service
  enable_now fwupd-refresh.timer
  # Developer services.
  enable_now bluetooth.service
  enable_now docker.service
  enable_now sshd.service

  log 'summary:'
  log "services/timers enabled: ${#ENABLED_UNITS[@]}"
  if [[ "${#ENABLED_UNITS[@]}" -gt 0 ]]; then
    printf '  - %s\n' "${ENABLED_UNITS[@]}"
  fi
  log "services/timers skipped: ${#SKIPPED_UNITS[@]}"
  if [[ "${#SKIPPED_UNITS[@]}" -gt 0 ]]; then
    printf '  - %s\n' "${SKIPPED_UNITS[@]}"
  fi
  log_success 'done'
}

# Entrypoint.
main "$@"
