#!/usr/bin/env bash
set -euo pipefail

PACKAGES_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_REPO_ROOT="$(cd "$PACKAGES_MODULE_DIR/../.." && pwd)"
PACKAGES_MANAGED_FILE="${PACKAGES_MANAGED_FILE:-$PACKAGES_MODULE_DIR/managed.conf}"
PACKAGES_LAST_PLAN_TYPE=''
PACKAGES_REQUIRED_MISSING=0
PACKAGES_DESIRED_UNAVAILABLE=0
PACKAGES_OPTIONAL_MISSING=0
PACKAGES_MANUAL_ACTIONS=0
PACKAGES_UNSUPPORTED_ACTIONS=0
PACKAGES_REQUIRED_MISSING_DNF=0
PACKAGES_REQUIRED_MISSING_COPRS=0
PACKAGES_COPR_SUPPORT_REPORTED=0
PACKAGES_TEST_ENABLED_COPRS=''

# shellcheck source=../../lib/log.sh
source "$PACKAGES_REPO_ROOT/lib/log.sh"
# shellcheck source=../../lib/command.sh
source "$PACKAGES_REPO_ROOT/lib/command.sh"

packages_each_entry() {
  local callback="$1"
  local line package_type package_name package_group package_importance package_notes extra
  shift

  [[ -f "$PACKAGES_MANAGED_FILE" ]] || {
    log_error "Managed packages config not found: $PACKAGES_MANAGED_FILE"
    return 1
  }

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "${line:0:1}" == '#' ]] && continue
    IFS=':' read -r package_type package_name package_group package_importance package_notes extra <<<"$line"
    if [[ -z "${package_type:-}" || -z "${package_name:-}" || -z "${package_group:-}" || -z "${package_importance:-}" || -n "${extra:-}" ]]; then
      log_error "Invalid managed packages entry: $line"
      return 1
    fi
    "$callback" "$package_type" "$package_name" "$package_group" "$package_importance" "${package_notes:-}" "$@"
  done <"$PACKAGES_MANAGED_FILE"
}

packages_validate_type() {
  local package_type="$1"

  case "$package_type" in
    dnf|dnf-optional|flatpak|repo|copr|appimage|npm-global|archive|rpm-url|manual|unsupported)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

packages_validate_importance() {
  local package_importance="$1"

  case "$package_importance" in
    required|desired|optional|manual|unsupported)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

packages_check_one() {
  local package_type="$1"
  local package_name="$2"
  local package_group="$3"
  local package_importance="$4"
  local package_notes="$5"

  if ! packages_validate_type "$package_type"; then
    log_error "Unsupported package inventory type: $package_type"
    return 1
  fi

  if ! packages_validate_importance "$package_importance"; then
    log_error "Unsupported package importance: $package_importance"
    return 1
  fi

  log_ok "Package inventory entry: $package_type:$package_name:$package_group:$package_importance:${package_notes}"
}

packages_dnf_installed() {
  local package_name="$1"

  if [[ "${SWAYDORA_TEST_MODE:-0}" == '1' ]]; then
    [[ " ${SWAYDORA_TEST_INSTALLED_DNF:-} " == *" $package_name "* ]]
    return $?
  fi

  command_exists rpm || return 1
  rpm -q "$package_name" >/dev/null 2>&1
}

packages_dnf_available() {
  local package_name="$1"

  if [[ "${SWAYDORA_TEST_MODE:-0}" == '1' ]]; then
    [[ " ${SWAYDORA_TEST_UNAVAILABLE_DNF:-} " == *" $package_name "* ]] && return 1
    return 0
  fi

  dnf list --available "$package_name" >/dev/null 2>&1
}

packages_plan_dnf() {
  local package_type="$1"
  local package_name="$2"
  local package_group="$3"
  local package_importance="$4"

  if [[ "${SWAYDORA_TEST_MODE:-0}" != '1' ]] && ! command_exists rpm; then
    log_warn "Cannot query rpm package state: $package_name [$package_group]"
    packages_count_unavailable "$package_importance"
    return 0
  fi

  if packages_dnf_installed "$package_name"; then
    log_ok "Installed $package_type package: $package_name [$package_group]"
  elif [[ "$package_type" == 'dnf' ]]; then
    if [[ "$package_importance" == 'required' ]]; then
      log_plan "Required dnf package missing: $package_name [$package_group]"
      PACKAGES_REQUIRED_MISSING_DNF=$((PACKAGES_REQUIRED_MISSING_DNF + 1))
    else
      log_plan "Would install $package_importance dnf package: $package_name [$package_group]"
    fi
    packages_count_unavailable "$package_importance"
  else
    log_info "Optional package not installed: $package_name [$package_group]"
    packages_count_unavailable "$package_importance"
  fi
}

packages_flatpak_installed() {
  local package_name="$1"

  command_exists flatpak || return 1
  flatpak info "$package_name" >/dev/null 2>&1
}

packages_repo_file_known() {
  local repo_name="$1"

  case "$repo_name" in
    vscode)
      [[ -f /etc/yum.repos.d/vscode.repo ]]
      ;;
    librewolf)
      [[ -f /etc/yum.repos.d/librewolf.repo ]] || [[ -f /etc/yum.repos.d/librewolf-rpm-repo.repo ]]
      ;;
    *)
      return 1
      ;;
  esac
}

packages_copr_known() {
  local copr_name="$1"
  local repo_pattern="${copr_name//\//:}"

  if [[ "${SWAYDORA_TEST_MODE:-0}" == '1' ]]; then
    [[ " ${SWAYDORA_TEST_CONFIGURED_COPRS:-} ${PACKAGES_TEST_ENABLED_COPRS:-} " == *" $copr_name "* ]]
    return $?
  fi

  find /etc/yum.repos.d \
    -maxdepth 1 \
    -type f \
    \( -name "*copr*${repo_pattern}*.repo" -o -name "*copr*${copr_name//\//-}*.repo" \) \
    -print -quit 2>/dev/null | grep -q .
}

packages_copr_support_package() {
  local package_name
  local -a candidates=(dnf-plugins-core dnf5-plugins)

  if [[ "${SWAYDORA_TEST_MODE:-0}" == '1' ]]; then
    [[ "${SWAYDORA_TEST_COPR_SUPPORT:-0}" == '1' ]] || return 1
    printf 'dnf-plugins-core\n'
    return 0
  fi

  command_exists rpm || return 1

  for package_name in "${candidates[@]}"; do
    if rpm -q "$package_name" >/dev/null 2>&1; then
      printf '%s\n' "$package_name"
      return 0
    fi
  done

  return 1
}

packages_copr_support_available() {
  packages_copr_support_package >/dev/null
}

packages_known_required_copr() {
  local copr_name="$1"

  case "$copr_name" in
    swayfx/swayfx)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

packages_count_unavailable() {
  local package_importance="$1"

  case "$package_importance" in
    required)
      PACKAGES_REQUIRED_MISSING=$((PACKAGES_REQUIRED_MISSING + 1))
      ;;
    desired)
      PACKAGES_DESIRED_UNAVAILABLE=$((PACKAGES_DESIRED_UNAVAILABLE + 1))
      ;;
    optional)
      PACKAGES_OPTIONAL_MISSING=$((PACKAGES_OPTIONAL_MISSING + 1))
      ;;
    manual)
      PACKAGES_MANUAL_ACTIONS=$((PACKAGES_MANUAL_ACTIONS + 1))
      ;;
    unsupported)
      PACKAGES_UNSUPPORTED_ACTIONS=$((PACKAGES_UNSUPPORTED_ACTIONS + 1))
      ;;
  esac
}

packages_plan_summary() {
  log_info 'Package summary:'
  log_info "- required missing dnf packages: $PACKAGES_REQUIRED_MISSING_DNF"
  log_info "- required missing COPRs: $PACKAGES_REQUIRED_MISSING_COPRS"
  log_info "- required missing total: $PACKAGES_REQUIRED_MISSING"
  log_info "- desired unavailable: $PACKAGES_DESIRED_UNAVAILABLE"
  log_info "- optional missing: $PACKAGES_OPTIONAL_MISSING"
  log_info "- manual actions: $PACKAGES_MANUAL_ACTIONS"
  log_info "- unsupported actions: $PACKAGES_UNSUPPORTED_ACTIONS"
}

packages_plan_copr_support() {
  local support_package

  if [[ "$PACKAGES_COPR_SUPPORT_REPORTED" -eq 1 ]]; then
    return 0
  fi
  PACKAGES_COPR_SUPPORT_REPORTED=1

  support_package="$(packages_copr_support_package || true)"
  if [[ -n "$support_package" ]]; then
    log_info "dnf copr support package installed: $support_package"
  else
    log_error 'COPR support package missing: dnf-plugins-core'
  fi
}

packages_log_unavailable() {
  local package_importance="$1"
  local message="$2"

  case "$package_importance" in
    optional|manual)
      log_info "$message"
      ;;
    *)
      log_warn "$message"
      ;;
  esac
}

packages_plan_header() {
  local package_type="$1"

  if [[ "$PACKAGES_LAST_PLAN_TYPE" != "$package_type" ]]; then
    log_info "Package category: $package_type"
    PACKAGES_LAST_PLAN_TYPE="$package_type"
  fi
}

packages_plan_one() {
  local package_type="$1"
  local package_name="$2"
  local package_group="$3"
  local package_importance="$4"
  local package_notes="$5"

  if ! packages_validate_importance "$package_importance"; then
    log_error "Unsupported package importance: $package_importance"
    return 1
  fi

  packages_plan_header "$package_type"

  case "$package_type" in
    dnf|dnf-optional)
      packages_plan_dnf "$package_type" "$package_name" "$package_group" "$package_importance"
      ;;
    flatpak)
      if ! command_exists flatpak; then
        log_warn "Cannot query flatpak state: $package_name [$package_group]"
        packages_count_unavailable "$package_importance"
      elif packages_flatpak_installed "$package_name"; then
        log_ok "Installed flatpak: $package_name [$package_group]"
      else
        log_plan "Missing flatpak: $package_name [$package_group]"
        packages_count_unavailable "$package_importance"
      fi
      ;;
    repo)
      if packages_repo_file_known "$package_name"; then
        log_ok "External repo configured: $package_name [$package_group]"
      else
        log_plan "External repo required: $package_name [$package_group]"
        packages_count_unavailable "$package_importance"
      fi
      ;;
    copr)
      packages_plan_copr_support
      if packages_copr_known "$package_name"; then
        log_ok "COPR repo configured: $package_name [$package_group]"
      else
        if [[ "$package_importance" == 'required' ]]; then
          log_plan "Required COPR missing: $package_name [$package_group]"
          log_plan "Would enable required COPR: $package_name"
          PACKAGES_REQUIRED_MISSING_COPRS=$((PACKAGES_REQUIRED_MISSING_COPRS + 1))
        else
          log_plan "COPR missing: $package_name [$package_group]"
        fi
        packages_count_unavailable "$package_importance"
      fi
      ;;
    appimage)
      if [[ "$package_importance" == 'desired' ]]; then
        packages_log_unavailable "$package_importance" "Desired AppImage not implemented: $package_name [$package_group]"
      else
        packages_log_unavailable "$package_importance" "AppImage install not implemented: $package_name [$package_group]"
      fi
      packages_count_unavailable "$package_importance"
      ;;
    npm-global)
      packages_log_unavailable "$package_importance" "npm global install not implemented: $package_name [$package_group]"
      packages_count_unavailable "$package_importance"
      ;;
    archive)
      packages_log_unavailable "$package_importance" "Archive install not implemented: $package_name [$package_group]"
      packages_count_unavailable "$package_importance"
      ;;
    rpm-url)
      packages_log_unavailable "$package_importance" "RPM URL install not implemented: $package_name [$package_group]"
      packages_count_unavailable "$package_importance"
      ;;
    manual)
      log_info "Manual post-install action: $package_name [$package_group]"
      packages_count_unavailable "$package_importance"
      ;;
    unsupported)
      log_warn "Unsupported package-side action not automated yet: $package_name [$package_group]"
      packages_count_unavailable "$package_importance"
      ;;
    *)
      log_error "Unsupported package inventory type: $package_type"
      return 1
      ;;
  esac
}

packages_check() {
  log_info 'Checking package inventory'
  packages_each_entry packages_check_one
}

packages_plan() {
  log_info 'Planning package inventory'
  PACKAGES_LAST_PLAN_TYPE=''
  PACKAGES_REQUIRED_MISSING=0
  PACKAGES_DESIRED_UNAVAILABLE=0
  PACKAGES_OPTIONAL_MISSING=0
  PACKAGES_MANUAL_ACTIONS=0
  PACKAGES_UNSUPPORTED_ACTIONS=0
  PACKAGES_REQUIRED_MISSING_DNF=0
  PACKAGES_REQUIRED_MISSING_COPRS=0
  PACKAGES_COPR_SUPPORT_REPORTED=0
  packages_each_entry packages_plan_one
  packages_plan_summary
}

packages_apply_supported() {
  return 0
}

packages_required_non_dnf() {
  local package_type="$1"
  local package_importance="$2"

  [[ "$package_type" == 'dnf' ]] && return 1
  [[ "$package_importance" == 'required' ]]
}

packages_preflight_apply_one() {
  local package_type="$1"
  local package_name="$2"
  local package_group="$3"
  local package_importance="$4"

  if ! packages_validate_type "$package_type"; then
    PACKAGES_APPLY_BLOCKERS+=("unsupported inventory type: $package_type")
    return 0
  fi

  if ! packages_validate_importance "$package_importance"; then
    PACKAGES_APPLY_BLOCKERS+=("unsupported importance: $package_importance")
    return 0
  fi

  if [[ "$package_type" == 'copr' && "$package_importance" == 'required' ]]; then
    PACKAGES_APPLY_REQUIRED_COPRS=$((PACKAGES_APPLY_REQUIRED_COPRS + 1))
    if ! packages_known_required_copr "$package_name"; then
      PACKAGES_APPLY_BLOCKERS+=("unknown required COPR: $package_name [$package_group]")
      return 0
    fi
    if ! packages_copr_known "$package_name"; then
      PACKAGES_APPLY_MISSING_COPRS+=("$package_name")
    fi
    return 0
  fi

  if packages_required_non_dnf "$package_type" "$package_importance"; then
    PACKAGES_APPLY_BLOCKERS+=("$package_type:$package_name [$package_group]")
  fi
}

packages_collect_apply_one() {
  local package_type="$1"
  local package_name="$2"
  local package_group="$3"
  local package_importance="$4"

  case "$package_type" in
    dnf)
      if packages_dnf_installed "$package_name"; then
        log_ok "Installed dnf package: $package_name [$package_group]"
      else
        case "$package_importance" in
          required)
            PACKAGES_APPLY_DNF_REQUIRED+=("$package_name")
            ;;
          desired)
            PACKAGES_APPLY_DNF_DESIRED+=("$package_name")
            ;;
          *)
            PACKAGES_APPLY_DNF_OPTIONAL+=("$package_name")
            ;;
        esac
      fi
      ;;
    *)
      log_warn "Skipping non-dnf package category during apply: $package_type:$package_name [$package_group]"
      ;;
  esac
}

packages_check_dnf_availability() {
  local package_name
  local unavail_required=0
  PACKAGES_APPLY_DNF_UNAVAIL_REQUIRED=()
  PACKAGES_APPLY_DNF_UNAVAIL_DESIRED=()
  PACKAGES_APPLY_DNF=()

  log_info 'Checking dnf package availability'

  for package_name in "${PACKAGES_APPLY_DNF_REQUIRED[@]}"; do
    if packages_dnf_available "$package_name"; then
      PACKAGES_APPLY_DNF+=("$package_name")
    else
      PACKAGES_APPLY_DNF_UNAVAIL_REQUIRED+=("$package_name")
      unavail_required=$((unavail_required + 1))
    fi
  done

  for package_name in "${PACKAGES_APPLY_DNF_DESIRED[@]}"; do
    if packages_dnf_available "$package_name"; then
      PACKAGES_APPLY_DNF+=("$package_name")
    else
      PACKAGES_APPLY_DNF_UNAVAIL_DESIRED+=("$package_name")
      log_warn "Desired dnf package unavailable, skipping: $package_name"
    fi
  done

  for package_name in "${PACKAGES_APPLY_DNF_OPTIONAL[@]}"; do
    if packages_dnf_available "$package_name"; then
      PACKAGES_APPLY_DNF+=("$package_name")
    else
      log_info "Optional dnf package unavailable, skipping: $package_name"
    fi
  done

  if [[ "$unavail_required" -gt 0 ]]; then
    log_error 'Unavailable required dnf packages block install:'
    printf '[ERROR] - %s\n' "${PACKAGES_APPLY_DNF_UNAVAIL_REQUIRED[@]}" >&2
    return 1
  fi

  return 0
}

packages_report_apply_blockers() {
  if [[ "${#PACKAGES_APPLY_MISSING_COPRS[@]}" -gt 0 ]]; then
    log_error 'Missing required COPR repositories:'
    printf '[ERROR] - %s\n' "${PACKAGES_APPLY_MISSING_COPRS[@]}" >&2
  fi

  if [[ "${#PACKAGES_APPLY_BLOCKERS[@]}" -gt 0 ]]; then
    log_error 'Cannot apply packages while required non-dnf entries are not implemented'
    printf '[ERROR] Required package blockers:\n' >&2
    printf '[ERROR] - %s\n' "${PACKAGES_APPLY_BLOCKERS[@]}" >&2
  fi

  if [[ "${PACKAGES_APPLY_COPR_SUPPORT_MISSING:-0}" == '1' ]]; then
    log_error 'Missing COPR support package: dnf-plugins-core'
  fi
}

packages_preflight() {
  PACKAGES_APPLY_BLOCKERS=()
  PACKAGES_APPLY_MISSING_COPRS=()
  PACKAGES_APPLY_REQUIRED_COPRS=0
  PACKAGES_APPLY_COPR_SUPPORT_MISSING=0

  log_info 'Preflighting package apply'
  packages_each_entry packages_preflight_apply_one || return 1

  if [[ "$PACKAGES_APPLY_REQUIRED_COPRS" -gt 0 ]] && ! packages_copr_support_available; then
    PACKAGES_APPLY_COPR_SUPPORT_MISSING=1
  fi

  if [[ "${#PACKAGES_APPLY_BLOCKERS[@]}" -gt 0 || "$PACKAGES_APPLY_COPR_SUPPORT_MISSING" -eq 1 ]]; then
    packages_report_apply_blockers
    return 1
  fi
}

packages_validate_apply_tools() {
  if [[ "${SWAYDORA_TEST_MODE:-0}" == '1' ]]; then
    return 0
  fi

  require_command rpm || return 1
  require_command dnf || return 1

  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    require_command sudo || return 1
  fi
}

packages_run_dnf_install() {
  local -a command_args

  if [[ "${SWAYDORA_TEST_MODE:-0}" == '1' ]]; then
    printf 'sudo dnf install -y'
    printf ' %s' "$@"
    printf '\n'
    return 0
  fi

  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    command_args=(dnf install -y "$@")
  else
    command_args=(sudo dnf install -y "$@")
  fi

  "${command_args[@]}"
}

packages_run_copr_enable() {
  local copr_name="$1"
  local -a command_args

  if [[ "${SWAYDORA_TEST_MODE:-0}" == '1' ]]; then
    if [[ "${SWAYDORA_TEST_COPR_ENABLE_FAIL:-0}" == '1' ]]; then
      return 1
    fi
    printf 'sudo dnf copr enable -y %s\n' "$copr_name"
    PACKAGES_TEST_ENABLED_COPRS="${PACKAGES_TEST_ENABLED_COPRS:+$PACKAGES_TEST_ENABLED_COPRS }$copr_name"
    return 0
  fi

  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    command_args=(dnf copr enable -y "$copr_name")
  else
    command_args=(sudo dnf copr enable -y "$copr_name")
  fi

  "${command_args[@]}"
}

packages_enable_required_coprs() {
  local copr_name

  for copr_name in "${PACKAGES_APPLY_MISSING_COPRS[@]}"; do
    log_info "Enabling required COPR: $copr_name"
    if ! packages_run_copr_enable "$copr_name"; then
      log_error "Failed to enable COPR: $copr_name"
      return 1
    fi

    if ! packages_copr_known "$copr_name"; then
      log_error "Required COPR still missing after enablement: $copr_name"
      return 1
    fi

    log_ok "Enabled COPR: $copr_name"
  done
}

packages_apply() {
  PACKAGES_APPLY_DNF_REQUIRED=()
  PACKAGES_APPLY_DNF_DESIRED=()
  PACKAGES_APPLY_DNF_OPTIONAL=()

  packages_preflight || return 1
  packages_validate_apply_tools || return 1
  packages_enable_required_coprs || return 1

  log_info 'Applying dnf package inventory'
  packages_each_entry packages_collect_apply_one || return 1

  packages_check_dnf_availability || return 1

  if [[ "${#PACKAGES_APPLY_DNF[@]}" -eq 0 ]]; then
    log_ok 'No missing dnf packages'
    return 0
  fi

  log_info "Installing dnf packages: ${PACKAGES_APPLY_DNF[*]}"
  packages_run_dnf_install "${PACKAGES_APPLY_DNF[@]}"
}
