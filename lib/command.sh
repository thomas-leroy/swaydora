#!/usr/bin/env bash
set -euo pipefail

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

require_command() {
  local command_name="$1"

  if ! command_exists "$command_name"; then
    log_error "Missing required command: $command_name"
    return 1
  fi
}
