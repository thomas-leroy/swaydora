#!/usr/bin/env bash
set -euo pipefail

# Print consistent log messages for this script.
log() {
  printf '[services] %s\n' "$*"
}

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
  else
    log "unit not found, skipping: $unit"
  fi
}

main() {
  # Enable required update/security timers and firewall service.
  enable_now dnf-automatic.timer
  enable_now dnf5-automatic.timer
  enable_now firewalld.service
  enable_now fwupd-refresh.timer
  # Developer services.
  enable_now docker.service
  enable_now sshd.service
  log 'done'
}

# Entrypoint.
main "$@"
