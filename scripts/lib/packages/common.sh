#!/usr/bin/env bash

is_dry_run() {
  [[ "${DRY_RUN:-0}" == '1' ]]
}

packages_info() {
  printf '[packages] %s\n' "$*"
}

packages_warn() {
  printf '[packages] WARN: %s\n' "$*" >&2
}

packages_error() {
  printf '[packages] ERROR: %s\n' "$*" >&2
}

packages_step() {
  printf '\n[packages] == %s ==\n' "$*"
}

packages_trace() {
  printf '[packages] %s\n' "$*" >&2
}

print_command() {
  local arg
  printf '+'
  for arg in "$@"; do
    printf ' %q' "$arg"
  done
  printf '\n'
}

run_cmd() {
  print_command "$@"
  if is_dry_run; then
    return 0
  fi
  "$@"
}

run_as_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    run_cmd "$@"
  else
    run_cmd sudo "$@"
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    packages_error "missing required command: $1"
    exit 1
  }
}

init_temp_dir() {
  if is_dry_run; then
    TEMP_DIR="${TMPDIR:-/tmp}/swaydora-packages.dry-run.$$"
    print_command mktemp -d "${TMPDIR:-/tmp}/swaydora-packages.XXXXXX"
    packages_info "DRY_RUN: would use temporary directory: $TEMP_DIR"
    return 0
  fi

  TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/swaydora-packages.XXXXXX")"
  packages_info "temporary directory created: $TEMP_DIR"
}

cleanup_temp_dir() {
  if [[ -z "${TEMP_DIR:-}" ]]; then
    return 0
  fi

  packages_info "cleaning up temporary directory: $TEMP_DIR"
  if is_dry_run; then
    print_command rm -rf "$TEMP_DIR"
  else
    rm -rf "$TEMP_DIR"
  fi
}

stop_blocking_package_managers() {
  local proc
  local -a user_processes=(pkcon packagekitd dnfdragora plasma-discover)

  packages_step 'Stop Blocking Package Managers'
  if is_dry_run; then
    packages_info 'DRY_RUN: would stop packagekit services and kill GUI package managers'
    return 0
  fi

  run_as_root systemctl stop packagekit.service || true
  run_as_root systemctl stop packagekit-offline-update.service || true

  for proc in "${user_processes[@]}"; do
    if pkill -x "$proc" >/dev/null 2>&1; then
      packages_info "stopped process: $proc"
    fi
  done

  sleep 1
}

download_file() {
  local url="$1"
  local destination="$2"

  packages_info "downloading: $url"
  if is_dry_run; then
    run_cmd timeout --foreground "$CURL_TIMEOUT_SEC" curl -fsSL "$url" -o "$destination"
    return 0
  fi

  if ! timeout --foreground "$CURL_TIMEOUT_SEC" curl -fsSL "$url" -o "$destination"; then
    packages_error "download failed or timed out after ${CURL_TIMEOUT_SEC}s: $url"
    return 1
  fi

  return 0
}

download_verified_sha256() {
  if [[ "$#" -ne 3 ]]; then
    packages_error 'usage: download_verified_sha256 <url> <expected_sha256> <destination>'
    return 1
  fi

  local url="$1"
  local expected_sha256="$2"
  local dest_path="$3"
  local tmp_name tmp_path actual_sha256

  require_cmd curl
  require_cmd sha256sum

  expected_sha256="${expected_sha256#sha256:}"
  if [[ -z "$expected_sha256" || -z "$url" || -z "$dest_path" ]]; then
    packages_error "invalid SHA256-verified download arguments for $url"
    return 1
  fi

  if [[ -z "${TEMP_DIR:-}" ]]; then
    packages_error 'temporary directory is not initialized'
    return 1
  fi

  tmp_name="$(basename "$dest_path").download"
  tmp_path="$TEMP_DIR/$tmp_name"
  run_cmd rm -f "$tmp_path"

  download_file "$url" "$tmp_path" || {
    rm -f "$tmp_path"
    return 1
  }

  if is_dry_run; then
    packages_info "DRY_RUN: would verify SHA256 for $tmp_path"
    run_cmd mv "$tmp_path" "$dest_path"
    return 0
  fi

  actual_sha256="$(sha256sum "$tmp_path" | awk '{print $1}')"
  packages_info "verifying SHA256 for $(basename "$dest_path")"
  if [[ "$actual_sha256" != "$expected_sha256" ]]; then
    packages_error "SHA256 mismatch for $url"
    packages_error "expected: $expected_sha256"
    packages_error "actual:   $actual_sha256"
    rm -f "$tmp_path"
    return 1
  fi

  mv "$tmp_path" "$dest_path"
  return 0
}

record_direct_package_install() {
  DIRECT_PACKAGE_INSTALLS+=("$1")
}

record_group_modification() {
  GROUP_MODIFICATIONS+=("$1")
}

record_file_action() {
  FILE_ACTIONS+=("$1")
}

record_service_action() {
  SERVICE_ACTIONS+=("$1")
}

record_shell_action() {
  SHELL_ACTIONS+=("$1")
}

record_install_action() {
  INSTALL_ACTIONS+=("$1")
}
