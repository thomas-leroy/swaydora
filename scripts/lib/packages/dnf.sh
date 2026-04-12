#!/usr/bin/env bash

pkg_is_installed() {
  rpm -q "$1" >/dev/null 2>&1
}

dnf_capture() {
  local description="$1"
  shift

  packages_trace "dnf query: $description"
  if ! timeout --foreground "$DNF_QUERY_TIMEOUT_SEC" dnf -q "$@" 2>/dev/null; then
    packages_warn "dnf query failed or timed out after ${DNF_QUERY_TIMEOUT_SEC}s: $description"
    return 1
  fi

  return 0
}

pkg_is_available() {
  local pkg="$1"
  local out

  out="$(dnf_capture "list --installed $pkg" list --installed "$pkg" || true)"
  if awk -v p="$pkg" '$1 ~ ("^" p "(\\.|$)") {found=1} END{exit(found ? 0 : 1)}' <<<"$out"; then
    return 0
  fi

  out="$(dnf_capture "list --available $pkg" list --available "$pkg" || true)"
  awk -v p="$pkg" '$1 ~ ("^" p "(\\.|$)") {found=1} END{exit(found ? 0 : 1)}' <<<"$out"
}

resolve_pkg() {
  local candidate

  packages_trace "resolving package candidates: $*"
  for candidate in "$@"; do
    packages_trace "checking package candidate: $candidate"
    if pkg_is_available "$candidate"; then
      packages_trace "selected package candidate: $candidate"
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  packages_warn "no package candidate matched: $*"
  return 1
}

install_pkg_now() {
  local pkg="$1"

  if pkg_is_installed "$pkg"; then
    packages_info "already installed: $pkg"
    return 0
  fi

  if ! pkg_is_available "$pkg"; then
    SKIPPED+=("$pkg")
    packages_warn "not available in enabled repos: $pkg"
    return 0
  fi

  record_direct_package_install "$pkg"
  packages_info "installing package via dnf: $pkg"
  run_as_root dnf install -y "$pkg"
}

queue_pkg() {
  local pkg="$1"

  if pkg_is_installed "$pkg"; then
    packages_info "already installed: $pkg"
    return 0
  fi

  if pkg_is_available "$pkg"; then
    TO_INSTALL+=("$pkg")
    packages_info "queued package: $pkg"
  elif is_dry_run; then
    TO_INSTALL+=("$pkg")
    packages_warn "DRY_RUN: package not currently available in repos, but keeping planned install: $pkg"
  else
    SKIPPED+=("$pkg")
    packages_warn "not available in enabled repos: $pkg"
  fi
}

install_queued() {
  if [[ "${#TO_INSTALL[@]}" -eq 0 ]]; then
    packages_info 'nothing to install via dnf'
    return 0
  fi

  packages_step 'Install DNF Packages'
  packages_info "packages to install: ${TO_INSTALL[*]}"
  run_as_root dnf install -y "${TO_INSTALL[@]}"
}

ensure_swayfx_installed_without_conflict() {
  if pkg_is_installed swayfx; then
    return 0
  fi

  if pkg_is_installed sway; then
    packages_info 'detected installed sway package, swapping to swayfx'
    run_as_root dnf swap -y --allowerasing sway swayfx
  fi
}

enable_vscode_repo_if_needed() {
  if pkg_is_available code || pkg_is_installed code; then
    return 0
  fi

  packages_info 'enabling Visual Studio Code repository'
  run_as_root rpm --import https://packages.microsoft.com/keys/microsoft.asc
  record_file_action "$VSCODE_REPO_FILE"
  run_as_root tee "$VSCODE_REPO_FILE" >/dev/null <<'EOT'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOT
}

enable_librewolf_repo_if_needed() {
  if pkg_is_available librewolf || pkg_is_installed librewolf; then
    return 0
  fi

  packages_info 'importing LibreWolf GPG key'
  run_as_root rpm --import "$LIBREWOLF_GPG_KEY_URL"

  if dnf -q repolist --all 2>/dev/null | awk 'NR > 1 && $1 == "librewolf" {found=1} END{exit(found ? 0 : 1)}'; then
    packages_info 'LibreWolf repository already configured'
    return 0
  fi

  packages_info 'enabling LibreWolf repository'
  run_as_root dnf config-manager addrepo --from-repofile "$LIBREWOLF_REPO_URL"
  record_service_action 'repo: librewolf'
}

ensure_copr_command() {
  if dnf -q copr list >/dev/null 2>&1; then
    return 0
  fi

  if ! pkg_is_installed dnf-plugins-core && pkg_is_available dnf-plugins-core; then
    packages_info 'installing dnf-plugins-core to enable COPR support'
    record_direct_package_install dnf-plugins-core
    run_as_root dnf install -y dnf-plugins-core
  fi

  if is_dry_run; then
    packages_info 'DRY_RUN: assuming dnf copr command would be available after planned setup'
    return 0
  fi

  if ! dnf -q copr list >/dev/null 2>&1; then
    packages_error 'dnf copr command is not available on this system'
    exit 1
  fi
}

enable_swayfx_copr_if_needed() {
  if pkg_is_available swayfx; then
    return 0
  fi

  packages_info "swayfx not found in current repos, enabling COPR: ${SWAYFX_COPR}"
  ensure_copr_command
  run_as_root dnf -y copr enable "${SWAYFX_COPR}"
  record_service_action "copr: ${SWAYFX_COPR}"
}

enable_swayosd_copr_if_needed() {
  if pkg_is_available swayosd; then
    return 0
  fi

  packages_info "swayosd not found in current repos, enabling COPR: ${SWAYOSD_COPR}"
  ensure_copr_command
  run_as_root dnf -y copr enable "${SWAYOSD_COPR}"
  record_service_action "copr: ${SWAYOSD_COPR}"
}
