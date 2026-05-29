#!/usr/bin/env bash
set -euo pipefail

DOCTOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=log.sh
source "$DOCTOR_DIR/log.sh"
# shellcheck source=command.sh
source "$DOCTOR_DIR/command.sh"
# shellcheck source=os.sh
source "$DOCTOR_DIR/os.sh"
# shellcheck source=git.sh
source "$DOCTOR_DIR/git.sh"

doctor_warn() {
  DOCTOR_WARNINGS=$((DOCTOR_WARNINGS + 1))
  log_warn "$@"
}

doctor_error() {
  DOCTOR_ERRORS=$((DOCTOR_ERRORS + 1))
  log_error "$@"
}

doctor_ok() {
  log_ok "$@"
}

run_doctor() {
  local repo_dir="${1:-.}"
  local required_commands=(bash git dnf systemctl loginctl swaymsg jq)
  local optional_commands=(distrobox wofi fuzzel wpctl notify-send)
  local command_name version branch

  DOCTOR_WARNINGS=0
  DOCTOR_ERRORS=0

  printf 'Swaydora doctor\n\n'

  if is_fedora; then
    if version="$(fedora_version 2>/dev/null)"; then
      doctor_ok "Fedora detected: $version"
    else
      doctor_error 'Fedora detected but version could not be read'
    fi
  else
    doctor_error 'Fedora not detected'
  fi

  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    doctor_error 'Running as root'
  else
    doctor_ok 'Running as normal user'
  fi

  for command_name in "${required_commands[@]}"; do
    if command_exists "$command_name"; then
      doctor_ok "Required command available: $command_name"
    else
      doctor_error "Missing required command: $command_name"
    fi
  done

  for command_name in "${optional_commands[@]}"; do
    if command_exists "$command_name"; then
      doctor_ok "Optional command available: $command_name"
    else
      doctor_warn "Missing optional command: $command_name"
    fi
  done

  if is_git_repo "$repo_dir"; then
    doctor_ok 'Repository is a Git repo'
    branch="$(git_branch "$repo_dir")"
    if [[ -n "$branch" ]]; then
      doctor_ok "Current Git branch: $branch"
    else
      doctor_warn 'Current Git branch could not be detected'
    fi

    if git_is_dirty "$repo_dir"; then
      doctor_warn 'Working tree has uncommitted changes'
    else
      doctor_ok 'Working tree is clean'
    fi
  else
    doctor_error 'Repository is not a Git repo'
  fi

  doctor_ok "Current session type: $(session_type)"
  doctor_ok "Current desktop session: $(desktop_session)"

  if [[ "$DOCTOR_ERRORS" -gt 0 ]]; then
    return 2
  fi

  if [[ "$DOCTOR_WARNINGS" -gt 0 ]]; then
    return 1
  fi

  return 0
}
