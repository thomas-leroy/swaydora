#!/usr/bin/env bash
set -euo pipefail

is_fedora() {
  [[ -r /etc/os-release ]] || return 1

  local os_id=''
  os_id="$(. /etc/os-release && printf '%s' "${ID:-}")"
  [[ "$os_id" == 'fedora' ]]
}

fedora_version() {
  [[ -r /etc/os-release ]] || return 1

  . /etc/os-release
  [[ -n "${VERSION_ID:-}" ]] || return 1
  printf '%s\n' "$VERSION_ID"
}

session_type() {
  printf '%s\n' "${XDG_SESSION_TYPE:-unknown}"
}

desktop_session() {
  printf '%s\n' "${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-unknown}}"
}
