#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/logging.sh"
setup_logger bootstrap

# Ensure a required command exists before running main steps.
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    log_error "missing required command: $1"
    exit 1
  }
}

main() {
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
