#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
INSTALL_HOME="${SWAYDORA_DISTROBOX_INSTALL_HOME:-/tmp/swaydora-fedora43-install-home}"
ASSUME_YES=0

print_help() {
  cat <<EOF
Usage:
  tests/distrobox/fedora-43-sway/install.sh --yes

Environment:
  SWAYDORA_DISTROBOX_INSTALL_HOME  Test HOME used for dotfile apply.

This runs the real workstation install inside the Fedora 43 container.
It mutates container packages and repositories, but uses a test HOME by default.
If DNF reports a container-only RPM scriptlet failure, the runner checks RPM
health and retries once before printing the remaining manual/post-install actions.
EOF
}

inside_container() {
  [[ -n "${DISTROBOX_ENTER_PATH:-}" ]] && return 0
  [[ -n "${CONTAINER_ID:-}" ]] && return 0
  [[ -f /run/.containerenv ]] && return 0
  [[ -f /.dockerenv ]] && return 0
  return 1
}

require_fedora_43() {
  local os_id version

  [[ -r /etc/os-release ]] || {
    printf 'Cannot read /etc/os-release\n' >&2
    return 1
  }

  # shellcheck source=/dev/null
  . /etc/os-release
  os_id="${ID:-}"
  version="${VERSION_ID:-}"

  if [[ "$os_id" != 'fedora' || "$version" != '43' ]]; then
    printf 'Expected Fedora 43 container, got ID=%s VERSION_ID=%s\n' "$os_id" "$version" >&2
    return 1
  fi
}

print_remaining_actions() {
  local plan_output

  plan_output="$(HOME="$INSTALL_HOME" bin/swaydora install --profile workstation --dry-run)"

  printf '\nRemaining post-install actions:\n'
  printf '%s\n' "$plan_output" | grep -E \
    'External repo required|Desired AppImage not implemented|AppImage install not implemented|RPM URL install not implemented|npm global install not implemented|Manual post-install action|Unsupported package-side action|Optional package not installed' \
    || printf 'No remaining manual actions reported.\n'

  printf '\nFull guidance: docs/post-install-manual-actions.md\n'
}

print_dnf_diagnostics() {
  printf '\nDNF diagnostics after failed install:\n'
  dnf history list | tail -n 8 || true

  printf '\nRecent DNF/RPM errors:\n'
  if [[ -r /var/log/dnf5.log ]]; then
    grep -E 'Transaction failed|Rpm transaction failed|scriptlet failed|return code [1-9]|ERROR|WARNING \[rpm\]' /var/log/dnf5.log | tail -n 20 || true
  else
    printf 'No readable /var/log/dnf5.log found.\n'
  fi
}

rpm_database_healthy() {
  printf '\nChecking RPM database health with dnf check...\n'
  dnf check
}

run_workstation_install() {
  HOME="$INSTALL_HOME" bin/swaydora install --profile workstation
}

run_install_with_recovery() {
  local install_status=0
  local retry_status=0

  run_workstation_install || install_status=$?
  if [[ "$install_status" -eq 0 ]]; then
    return 0
  fi

  printf '\nWorkstation install exited with status %s.\n' "$install_status" >&2
  print_dnf_diagnostics

  if ! rpm_database_healthy; then
    printf '\nRPM database check failed. Stop here and inspect the DNF diagnostics above.\n' >&2
    return "$install_status"
  fi

  printf '\nRPM database looks healthy. Retrying install once to finish idempotent steps.\n'
  run_workstation_install || retry_status=$?
  if [[ "$retry_status" -ne 0 ]]; then
    printf '\nRetry exited with status %s. Stop here and inspect the logs above.\n' "$retry_status" >&2
    return "$retry_status"
  fi
}

main() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --yes)
        ASSUME_YES=1
        shift
        ;;
      -h|--help)
        print_help
        return 0
        ;;
      *)
        printf 'Unsupported option: %s\n\n' "$1" >&2
        print_help >&2
        return 2
        ;;
    esac
  done

  if [[ "$ASSUME_YES" -ne 1 ]]; then
    printf 'This runs a real install in the Fedora 43 container. Pass --yes to continue.\n' >&2
    return 2
  fi

  inside_container || {
    printf 'Run this script from inside Distrobox.\n' >&2
    return 1
  }
  require_fedora_43

  mkdir -p "$INSTALL_HOME"
  cd "$ROOT_DIR"

  printf 'Running real workstation install in Fedora 43 Distrobox.\n'
  printf 'Container packages/repositories may change.\n'
  printf 'Test HOME: %s\n\n' "$INSTALL_HOME"

  run_install_with_recovery
  print_remaining_actions
}

main "$@"
