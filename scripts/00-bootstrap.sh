#!/usr/bin/env bash
set -euo pipefail

# Print consistent log messages for this script.
log() {
  printf '[bootstrap] %s\n' "$*"
}

# Ensure a required command exists before running main steps.
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf '[bootstrap] missing required command: %s\n' "$1" >&2
    exit 1
  }
}

main() {
  # Validate dependencies used by this script.
  require_cmd mkdir

  # Create base directories used by setup/runtime scripts.
  log 'creating user config and cache directories'
  mkdir -p "$HOME/.config" "$HOME/.local/share/fonts" "$HOME/.cache/dotfiles"

  log 'done'
}

# Entrypoint.
main "$@"
