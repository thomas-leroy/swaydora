#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
EXPECTED_FEDORA_VERSION="${SWAYDORA_EXPECTED_FEDORA_VERSION:-44}"

cd "$ROOT_DIR"

log_step() {
  printf '\n== %s ==\n' "$*"
}

inside_container() {
  [[ -n "${DISTROBOX_ENTER_PATH:-}" ]] && return 0
  [[ -n "${CONTAINER_ID:-}" ]] && return 0
  [[ -f /run/.containerenv ]] && return 0
  [[ -f /.dockerenv ]] && return 0
  return 1
}

os_value() {
  local key="$1"

  [[ -r /etc/os-release ]] || return 1
  # shellcheck source=/dev/null
  . /etc/os-release
  case "$key" in
    ID)
      printf '%s\n' "${ID:-}"
      ;;
    VERSION_ID)
      printf '%s\n' "${VERSION_ID:-}"
      ;;
    PRETTY_NAME)
      printf '%s\n' "${PRETTY_NAME:-}"
      ;;
    *)
      return 1
      ;;
  esac
}

require_fedora_44() {
  local os_id version pretty

  os_id="$(os_value ID)"
  version="$(os_value VERSION_ID)"
  pretty="$(os_value PRETTY_NAME)"

  printf 'Detected OS: %s\n' "$pretty"

  if [[ "$os_id" != 'fedora' ]]; then
    printf 'Expected Fedora container, got ID=%s\n' "$os_id" >&2
    return 1
  fi

  if [[ "$version" != "$EXPECTED_FEDORA_VERSION" ]]; then
    printf 'Expected Fedora %s, got VERSION_ID=%s\n' "$EXPECTED_FEDORA_VERSION" "$version" >&2
    return 1
  fi
}

print_command_inventory() {
  local command_name
  local -a commands=(bash git dnf rpm systemctl loginctl swaymsg jq distrobox wofi fuzzel wpctl notify-send)

  for command_name in "${commands[@]}"; do
    if command -v "$command_name" >/dev/null 2>&1; then
      printf '[OK] command available: %s\n' "$command_name"
    else
      printf '[BLOCKER] command missing in Fedora 44 container: %s\n' "$command_name"
    fi
  done
}

print_install_blockers() {
  local plan_output="$1"

  printf '%s\n' "$plan_output" | grep -E \
    '^\[(ERROR|WARN|PLAN)\] |Required .* missing|External repo required|not implemented|Manual post-install action|Unsupported package-side action' \
    || true
}

run_workstation_dry_run() {
  local plan_output

  plan_output="$(bin/swaydora install --profile workstation --dry-run)"
  printf '%s\n' "$plan_output"

  log_step 'Fedora 44 Install Blocker Summary'
  print_install_blockers "$plan_output"
}

main() {
  log_step 'Fedora 44 Target'
  if inside_container; then
    printf 'Container environment detected.\n'
  else
    printf 'Warning: container environment not detected; continuing target checks.\n'
  fi
  require_fedora_44

  log_step 'Command Inventory'
  print_command_inventory

  log_step 'Shared Distrobox Validation'
  tests/distrobox/run.sh

  log_step 'Workstation Dry Run'
  run_workstation_dry_run
}

main "$@"
