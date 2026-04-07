#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/logging.sh"
setup_logger packages

# Optional flag: install virtualization stack when set to 1.
WITH_VIRT="${WITH_VIRT:-0}"
# Optional flag: print planned actions without changing the system.
DRY_RUN="${DRY_RUN:-0}"
# Optional flag: auto-add current user to video group when missing (enabled by default).
AUTO_ADD_VIDEO_GROUP="${AUTO_ADD_VIDEO_GROUP:-1}"
# Optional flag: fail if swayfx is unavailable (enabled by default).
REQUIRE_SWAYFX="${REQUIRE_SWAYFX:-1}"
# COPR repo used to install swayfx when not in default enabled repos.
SWAYFX_COPR="${SWAYFX_COPR:-swayfx/swayfx}"
# COPR repo used to install swayosd when not in default enabled repos.
SWAYOSD_COPR="${SWAYOSD_COPR:-erikreider/swayosd}"
# LibreWolf official repository and key.
LIBREWOLF_REPO_URL="${LIBREWOLF_REPO_URL:-https://repo.librewolf.net/librewolf.repo}"
LIBREWOLF_GPG_KEY_URL="${LIBREWOLF_GPG_KEY_URL:-https://repo.librewolf.net/pubkey.gpg}"
# Handy official RPM used when the package is not available in enabled repos.
HANDY_RPM_URL="${HANDY_RPM_URL:-https://github.com/cjpais/Handy/releases/download/v0.8.1/Handy-0.8.1-1.x86_64.rpm}"
# Obsidian official AppImage used when no distro package is available.
OBSIDIAN_APPIMAGE_URL="${OBSIDIAN_APPIMAGE_URL:-https://github.com/obsidianmd/obsidian-releases/releases/download/v1.10.6/Obsidian-1.10.6.AppImage}"
OBSIDIAN_APPIMAGE_SHA256="${OBSIDIAN_APPIMAGE_SHA256:-162d753076d0610e4dccfdccf391c13af5fcb557ba7574b77f0e90ac3c522b1c}"
# Insomnia official AppImage used when no distro package is available.
INSOMNIA_VERSION="${INSOMNIA_VERSION:-12.5.0}"
INSOMNIA_APPIMAGE_URL="${INSOMNIA_APPIMAGE_URL:-https://github.com/Kong/insomnia/releases/download/core@${INSOMNIA_VERSION}/Insomnia.Core-${INSOMNIA_VERSION}.AppImage}"
INSOMNIA_APPIMAGE_SHA256="${INSOMNIA_APPIMAGE_SHA256:-458373397f5644fa8f50c85b1bf01be08a76e629ae74d1a51d7d643cbcee43e5}"
# LocalSend official AppImage used when no distro package is available.
LOCALSEND_APPIMAGE_URL="${LOCALSEND_APPIMAGE_URL:-https://github.com/localsend/localsend/releases/download/v1.17.0/LocalSend-1.17.0-linux-x86-64.AppImage}"
LOCALSEND_APPIMAGE_SHA256="${LOCALSEND_APPIMAGE_SHA256:-c1a1e7bc7bb7eebdf6c365a30cef0d4ba3e6bb79961c3b94edf918920f8e36f0}"
# Bluetuith official release archive used when no distro package is available.
BLUETUITH_ARCHIVE_URL="${BLUETUITH_ARCHIVE_URL:-https://github.com/bluetuith-org/bluetuith/releases/download/v0.2.6/bluetuith_0.2.6_Linux_x86_64.tar.gz}"
# VS Code official repository file.
VSCODE_REPO_FILE='/etc/yum.repos.d/vscode.repo'
# Oh My Zsh official repository used for manual installation.
OH_MY_ZSH_REPO_URL="${OH_MY_ZSH_REPO_URL:-https://github.com/ohmyzsh/ohmyzsh.git}"
OH_MY_ZSH_REF="${OH_MY_ZSH_REF:-master}"
MIN_FEDORA_VERSION="${MIN_FEDORA_VERSION:-43}"
MIN_DISK_KIB="${MIN_DISK_KIB:-8388608}"
MIN_RAM_KIB="${MIN_RAM_KIB:-8388608}"

TEMP_DIR=''

is_dry_run() {
  [[ "$DRY_RUN" == '1' ]]
}

print_command() {
  log_command "$@"
}

run_cmd() {
  if is_dry_run; then
    print_command "$@"
    return 0
  fi

  "$@"
}

init_temp_dir() {
  if is_dry_run; then
    TEMP_DIR="${TMPDIR:-/tmp}/swaydora-packages.dry-run.$$"
    print_command mktemp -d "${TMPDIR:-/tmp}/swaydora-packages.XXXXXX"
    log "DRY_RUN: would use temporary directory: $TEMP_DIR"
    return 0
  fi

  TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/swaydora-packages.XXXXXX")"
  log "temporary directory created: $TEMP_DIR"
}

cleanup_temp_dir() {
  if [[ -z "${TEMP_DIR:-}" ]]; then
    return 0
  fi

  log "cleaning up temporary directory: $TEMP_DIR"
  if is_dry_run; then
    print_command rm -rf "$TEMP_DIR"
  else
    rm -rf "$TEMP_DIR"
  fi
}

trap cleanup_temp_dir EXIT

ensure_no_competing_pkg_manager() {
  local matches

  matches="$(ps -eo pid=,comm=,args= | awk -v self="$$" '
    {
      pid=$1
      comm=$2
      if (pid == self) next
      if (comm == "dnf" || comm == "dnf5" || comm == "packagekitd" || comm == "pkcon" || comm == "rpm") print
    }
  ' || true)"

  if [[ -n "$matches" ]]; then
    log_error 'another package-management process is already running; aborting to avoid freezes/conflicts'
    printf '%s\n' "$matches" >&2
    log_error 'close/stop that process, then rerun 10-packages.sh'
    exit 1
  fi
}

# Run privileged commands with sudo when not root.
run_as_root() {
  if is_dry_run; then
    if [[ "${EUID}" -eq 0 ]]; then
      print_command "$@"
    else
      print_command sudo "$@"
    fi
    return 0
  fi

  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

# Ensure required command is available.
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    log_error "missing required command: $1"
    exit 1
  }
}

fail_requirement() {
  log_error "$1"
  log_error 'This setup script is provided as-is and has not been tested on other configurations.'
  log_error 'If your machine does not match these requirements, I recommend picking individual pieces from the dotfiles instead of running the full setup.'
  exit 1
}

check_system_requirements() {
  local fedora_id fedora_version disk_available_kib ram_available_kib cmd
  local -a critical_commands

  log 'checking system requirements'

  if [[ ! -r /etc/os-release ]]; then
    fail_requirement '/etc/os-release not found; cannot verify Fedora version.'
  fi

  # shellcheck disable=SC1091
  source /etc/os-release
  fedora_id="${ID:-}"
  fedora_version="${VERSION_ID:-0}"

  if [[ "$fedora_id" != 'fedora' ]]; then
    fail_requirement "unsupported distribution: ${fedora_id:-unknown}; Fedora ${MIN_FEDORA_VERSION}+ is required."
  fi
  if [[ ! "$fedora_version" =~ ^[0-9]+$ || "$fedora_version" -lt "$MIN_FEDORA_VERSION" ]]; then
    fail_requirement "unsupported Fedora version: ${fedora_version:-unknown}; Fedora ${MIN_FEDORA_VERSION}+ is required."
  fi

  disk_available_kib="$(df -Pk "$HOME" | awk 'NR == 2 {print $4}')"
  if [[ ! "$disk_available_kib" =~ ^[0-9]+$ || "$disk_available_kib" -le "$MIN_DISK_KIB" ]]; then
    fail_requirement "not enough free disk space under $HOME: ${disk_available_kib:-unknown} KiB available; more than $MIN_DISK_KIB KiB is required."
  fi

  ram_available_kib="$(awk '/^MemAvailable:/ {print $2; exit}' /proc/meminfo)"
  if [[ ! "$ram_available_kib" =~ ^[0-9]+$ || "$ram_available_kib" -le "$MIN_RAM_KIB" ]]; then
    fail_requirement "not enough available RAM: ${ram_available_kib:-unknown} KiB available; more than $MIN_RAM_KIB KiB is required."
  fi

  critical_commands=(dnf curl tar gzip)
  for cmd in "${critical_commands[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      fail_requirement "missing critical command: $cmd"
    fi
  done

  log_success "system requirements satisfied: Fedora $fedora_version, disk/RAM thresholds met, critical commands present"
}

# Download a file and verify its SHA256 before moving it into place.
download_verified_sha256() {
  if [[ "$#" -ne 3 ]]; then
    log_error 'usage: download_verified_sha256 <url> <expected_sha256> <destination>'
    return 1
  fi

  local url="$1"
  local expected_sha256="$2"
  local dest_path="$3"
  local tmp_name tmp_path actual_sha256

  require_cmd curl
  require_cmd sha256sum

  expected_sha256="${expected_sha256#sha256:}"
  if [[ -z "$expected_sha256" ]]; then
    log_error "missing expected SHA256 for $url"
    return 1
  fi
  if [[ -z "$url" || -z "$dest_path" ]]; then
    log_error 'missing download URL or destination for SHA256-verified download'
    return 1
  fi

  if [[ -z "${TEMP_DIR:-}" ]]; then
    log_error 'temporary directory is not initialized'
    return 1
  fi

  tmp_name="$(basename "$dest_path").download"
  tmp_path="$TEMP_DIR/$tmp_name"
  run_cmd rm -f "$tmp_path"

  if is_dry_run; then
    run_cmd curl -fsSL "$url" -o "$tmp_path"
    log "DRY_RUN: would verify SHA256 for $tmp_path (expected: $expected_sha256)"
    run_cmd mv "$tmp_path" "$dest_path"
    return 0
  fi

  if ! curl -fsSL "$url" -o "$tmp_path"; then
    log_error "download failed: $url"
    rm -f "$tmp_path"
    return 1
  fi

  actual_sha256="$(sha256sum "$tmp_path" | awk '{print $1}')"
  if [[ "$actual_sha256" != "$expected_sha256" ]]; then
    log_error "SHA256 mismatch for $url"
    log_error "expected: $expected_sha256"
    log_error "actual:   $actual_sha256"
    log_error "deleting corrupted download: $tmp_path"
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

install_pkg_now() {
  local pkg="$1"

  if pkg_is_installed "$pkg"; then
    log_success "already installed: $pkg"
    return 0
  fi

  if ! pkg_is_available "$pkg"; then
    SKIPPED+=("$pkg")
    log_warn "not available in enabled repos: $pkg"
    return 0
  fi

  record_direct_package_install "$pkg"
  if is_dry_run; then
    log "package would be installed: $pkg"
  else
    log "installing package: $pkg"
  fi
  run_as_root dnf install -y "$pkg"
}

# Return success when a package is already installed.
pkg_is_installed() {
  rpm -q "$1" >/dev/null 2>&1
}

# Return success when a package exists in enabled repos or is already installed.
pkg_is_available() {
  local pkg="$1"
  local out

  # Check installed packages first to avoid expensive repo probes when the
  # package is already present locally.
  out="$(dnf -q list --installed "$pkg" 2>/dev/null || true)"
  if awk -v p="$pkg" '$1 ~ ("^" p "(\\.|$)") {found=1} END{exit(found ? 0 : 1)}' <<<"$out"; then
    return 0
  fi

  # Check exact package match in available packages.
  out="$(dnf -q list --available "$pkg" 2>/dev/null || true)"
  awk -v p="$pkg" '$1 ~ ("^" p "(\\.|$)") {found=1} END{exit(found ? 0 : 1)}' <<<"$out"
}

# Pick the first package name variant that exists.
resolve_pkg() {
  local candidate
  for candidate in "$@"; do
    if pkg_is_available "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

# Queue an installable package, or mark it as skipped.
queue_pkg() {
  local pkg="$1"
  if pkg_is_installed "$pkg"; then
    log_success "already installed: $pkg"
    return 0
  fi
  if pkg_is_available "$pkg"; then
    TO_INSTALL+=("$pkg")
    log "queued: $pkg"
  elif is_dry_run; then
    TO_INSTALL+=("$pkg")
    log "DRY_RUN: would attempt package install even though not currently available in enabled repos: $pkg"
  else
    SKIPPED+=("$pkg")
    log_warn "not available in enabled repos: $pkg"
  fi
}

# Install all queued packages in one dnf transaction.
install_queued() {
  if [[ "${#TO_INSTALL[@]}" -eq 0 ]]; then
    log 'nothing to install'
    return 0
  fi
  if is_dry_run; then
    log "${#TO_INSTALL[@]} package(s) would be installed"
  else
    log "installing ${#TO_INSTALL[@]} package(s)"
  fi
  run_as_root dnf install -y "${TO_INSTALL[@]}"
}

# Replace plain sway with swayfx when sway is already installed.
ensure_swayfx_installed_without_conflict() {
  if pkg_is_installed swayfx; then
    return 0
  fi

  if pkg_is_installed sway; then
    log 'detected installed sway package, swapping to swayfx'
    run_as_root dnf swap -y --allowerasing sway swayfx
  fi
}

# Enable official VS Code repository when `code` package is missing.
enable_vscode_repo_if_needed() {
  if pkg_is_available code || pkg_is_installed code; then
    return 0
  fi

  log 'enabling Visual Studio Code repository'
  run_as_root rpm --import https://packages.microsoft.com/keys/microsoft.asc
  run_as_root tee "$VSCODE_REPO_FILE" >/dev/null <<'EOT'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOT
}

# Enable LibreWolf repository and import its GPG key up front to avoid
# interactive trust prompts during package installation.
enable_librewolf_repo_if_needed() {
  if pkg_is_available librewolf || pkg_is_installed librewolf; then
    return 0
  fi

  log 'importing LibreWolf GPG key'
  run_as_root rpm --import "$LIBREWOLF_GPG_KEY_URL"

  if dnf -q repolist --all 2>/dev/null | awk 'NR > 1 && $1 == "librewolf" {found=1} END{exit(found ? 0 : 1)}'; then
    log 'LibreWolf repository already configured'
    return 0
  fi

  log 'enabling LibreWolf repository'
  run_as_root dnf config-manager addrepo --from-repofile "$LIBREWOLF_REPO_URL"
}

# Ensure `dnf copr` command is available.
ensure_copr_command() {
  if dnf -q copr list >/dev/null 2>&1; then
    return 0
  fi

  # Install plugin package when needed.
  if ! pkg_is_installed dnf-plugins-core && pkg_is_available dnf-plugins-core; then
    log 'installing dnf-plugins-core to enable COPR command support'
    record_direct_package_install dnf-plugins-core
    run_as_root dnf install -y dnf-plugins-core
  fi

  if is_dry_run; then
    log 'DRY_RUN: assuming dnf copr command would be available after planned setup'
    return 0
  fi

  dnf -q copr list >/dev/null 2>&1 || {
    log_error 'dnf copr command is not available on this system'
    exit 1
  }
}

# Enable swayfx COPR when swayfx package is not available yet.
enable_swayfx_copr_if_needed() {
  if pkg_is_available swayfx; then
    return 0
  fi

  log "swayfx not found in current repos, enabling COPR: ${SWAYFX_COPR}"
  ensure_copr_command
  run_as_root dnf -y copr enable "${SWAYFX_COPR}"
}

# Enable swayosd COPR when swayosd package is not available yet.
enable_swayosd_copr_if_needed() {
  if pkg_is_available swayosd; then
    return 0
  fi

  log "swayosd not found in current repos, enabling COPR: ${SWAYOSD_COPR}"
  ensure_copr_command
  run_as_root dnf -y copr enable "${SWAYOSD_COPR}"
}

# Verify whether current user can access brightness/video related devices.
check_video_group_membership() {
  if ! getent group video >/dev/null 2>&1; then
    log_warn 'group "video" does not exist on this system, skipping group check'
    return 0
  fi

  if id -nG "$USER" | grep -qw video; then
    log_success "user $USER is already in group: video"
    return 0
  fi

  if [[ "$AUTO_ADD_VIDEO_GROUP" == '1' ]]; then
    if is_dry_run; then
      log "DRY_RUN: would add $USER to group video (AUTO_ADD_VIDEO_GROUP=1)"
    else
      log "adding $USER to group video (AUTO_ADD_VIDEO_GROUP=1)"
    fi
    record_group_modification "$USER -> video"
    run_as_root usermod -aG video "$USER"
    if is_dry_run; then
      log 'DRY_RUN: group membership would be updated; logout/login would be required'
    else
      log 'group updated; logout/login is required to apply new group membership'
    fi
  else
    log_warn "user $USER is not in group video; set AUTO_ADD_VIDEO_GROUP=1 to add automatically"
  fi
}

# Ensure current user can use Docker without sudo.
check_docker_group_membership() {
  if ! getent group docker >/dev/null 2>&1; then
    log_warn 'group "docker" does not exist yet, skipping docker group update'
    return 0
  fi

  if id -nG "$USER" | grep -qw docker; then
    log_success "user $USER is already in group: docker"
    return 0
  fi

  if is_dry_run; then
    log "DRY_RUN: would add $USER to group docker"
  else
    log "adding $USER to group docker"
  fi
  record_group_modification "$USER -> docker"
  run_as_root usermod -aG docker "$USER"
  if is_dry_run; then
    log 'DRY_RUN: docker group membership would be updated; logout/login would be required'
  else
    log 'docker group updated; logout/login is required to apply new group membership'
  fi
}

# Install pnpm globally when distro package is unavailable.
ensure_pnpm_installed() {
  if command -v pnpm >/dev/null 2>&1; then
    log_success 'pnpm already installed'
    return 0
  fi

  if ! command -v npm >/dev/null 2>&1; then
    log_warn 'npm not found, skipping pnpm fallback install'
    return 0
  fi

  log 'installing pnpm globally via npm fallback'
  run_as_root npm install -g pnpm
}

# Install Handy from its official RPM when it is not available in repos yet.
ensure_handy_installed() {
  if command -v handy >/dev/null 2>&1; then
    log_success 'Handy already installed'
    return 0
  fi

  if pkg_is_available handy; then
    install_pkg_now handy
    return 0
  fi

  if is_dry_run; then
    log "DRY_RUN: would install Handy from official RPM: ${HANDY_RPM_URL}"
  else
    log "installing Handy from official RPM: ${HANDY_RPM_URL}"
  fi
  record_direct_package_install "$HANDY_RPM_URL"
  run_as_root dnf install -y "$HANDY_RPM_URL"
}

# Install Obsidian using distro package when available, otherwise the official AppImage.
ensure_obsidian_installed() {
  local install_dir appimage_path launcher_path

  if command -v obsidian >/dev/null 2>&1; then
    log_success 'Obsidian already installed'
    return 0
  fi

  if pkg_is_available obsidian; then
    install_pkg_now obsidian
    return 0
  fi

  install_dir="$HOME/.local/opt/obsidian"
  appimage_path="$install_dir/Obsidian.AppImage"
  launcher_path="$HOME/.local/bin/obsidian"

  run_cmd mkdir -p "$install_dir" "$HOME/.local/bin"
  if is_dry_run; then
    log "DRY_RUN: would install Obsidian from official AppImage: ${OBSIDIAN_APPIMAGE_URL}"
  else
    log "installing Obsidian from official AppImage: ${OBSIDIAN_APPIMAGE_URL}"
  fi
  download_verified_sha256 "$OBSIDIAN_APPIMAGE_URL" "$OBSIDIAN_APPIMAGE_SHA256" "$appimage_path"
  run_cmd chmod +x "$appimage_path"
  run_cmd ln -sfn "$appimage_path" "$launcher_path"
}

# Install LocalSend using distro package when available, otherwise the official AppImage.
ensure_localsend_installed() {
  local install_dir appimage_path launcher_path desktop_dir desktop_file

  if command -v localsend >/dev/null 2>&1 || command -v localsend_app >/dev/null 2>&1; then
    log_success 'LocalSend already installed'
    return 0
  fi

  if pkg_is_available localsend; then
    install_pkg_now localsend
    return 0
  fi

  install_dir="$HOME/.local/opt/localsend"
  appimage_path="$install_dir/LocalSend.AppImage"
  launcher_path="$HOME/.local/bin/localsend"
  desktop_dir="$HOME/.local/share/applications"
  desktop_file="$desktop_dir/org.localsend.localsend_app.desktop"

  run_cmd mkdir -p "$install_dir" "$HOME/.local/bin" "$desktop_dir"
  if is_dry_run; then
    log "DRY_RUN: would install LocalSend from official AppImage: ${LOCALSEND_APPIMAGE_URL}"
  else
    log "installing LocalSend from official AppImage: ${LOCALSEND_APPIMAGE_URL}"
  fi
  download_verified_sha256 "$LOCALSEND_APPIMAGE_URL" "$LOCALSEND_APPIMAGE_SHA256" "$appimage_path"
  run_cmd chmod +x "$appimage_path"
  run_cmd ln -sfn "$appimage_path" "$launcher_path"
  if is_dry_run; then
    log "DRY_RUN: would write desktop entry: $desktop_file"
    return 0
  fi
  cat > "$desktop_file" <<EOT
[Desktop Entry]
Type=Application
Name=LocalSend
Comment=Share files with nearby devices
Exec=$launcher_path
Icon=org.localsend.localsend_app
Terminal=false
Categories=Network;FileTransfer;
StartupNotify=true
EOT
}

# Install Insomnia using distro package when available, otherwise the official AppImage.
ensure_insomnia_installed() {
  local install_dir appimage_path launcher_path desktop_dir desktop_file

  if command -v insomnia >/dev/null 2>&1; then
    log_success 'Insomnia already installed'
    return 0
  fi

  if pkg_is_available insomnia; then
    if pkg_is_installed insomnia; then
      log_success 'Insomnia already installed'
    else
      record_direct_package_install insomnia
      if is_dry_run; then
        log 'DRY_RUN: would install Insomnia from enabled repos'
      else
        log 'installing Insomnia from enabled repos'
      fi
      run_as_root dnf install -y insomnia
    fi
    return 0
  fi

  install_dir="$HOME/.local/opt/insomnia"
  appimage_path="$install_dir/Insomnia.AppImage"
  launcher_path="$HOME/.local/bin/insomnia"
  desktop_dir="$HOME/.local/share/applications"
  desktop_file="$desktop_dir/insomnia.desktop"

  run_cmd mkdir -p "$install_dir" "$HOME/.local/bin" "$desktop_dir"
  if is_dry_run; then
    log "DRY_RUN: would install Insomnia from official AppImage: ${INSOMNIA_APPIMAGE_URL}"
  else
    log "installing Insomnia from official AppImage: ${INSOMNIA_APPIMAGE_URL}"
  fi
  download_verified_sha256 "$INSOMNIA_APPIMAGE_URL" "$INSOMNIA_APPIMAGE_SHA256" "$appimage_path"
  run_cmd chmod +x "$appimage_path"
  run_cmd ln -sfn "$appimage_path" "$launcher_path"
  if is_dry_run; then
    log "DRY_RUN: would write desktop entry: $desktop_file"
    return 0
  fi
  cat > "$desktop_file" <<EOT
[Desktop Entry]
Type=Application
Name=Insomnia
Comment=API client for REST, GraphQL, gRPC, and more
Exec=$launcher_path
Icon=insomnia
Terminal=false
Categories=Development;Network;
StartupNotify=true
EOT
}

# Install Bluetuith using distro package when available, otherwise the official release archive.
ensure_bluetuith_installed() {
  local install_dir archive_path binary_path launcher_path tmp_dir

  if command -v bluetuith >/dev/null 2>&1; then
    log_success 'Bluetuith already installed'
    return 0
  fi

  if pkg_is_available bluetuith; then
    install_pkg_now bluetuith
    return 0
  fi

  require_cmd curl
  require_cmd tar
  install_dir="$HOME/.local/opt/bluetuith"
  if [[ -z "${TEMP_DIR:-}" ]]; then
    log_error 'temporary directory is not initialized'
    return 1
  fi

  archive_path="$TEMP_DIR/bluetuith.tar.gz"
  binary_path="$install_dir/bluetuith"
  launcher_path="$HOME/.local/bin/bluetuith"
  tmp_dir="$TEMP_DIR/bluetuith.extract"

  run_cmd mkdir -p "$install_dir" "$HOME/.local/bin" "$tmp_dir"
  if is_dry_run; then
    log "DRY_RUN: would install Bluetuith from official release: ${BLUETUITH_ARCHIVE_URL}"
  else
    log "installing Bluetuith from official release: ${BLUETUITH_ARCHIVE_URL}"
  fi
  run_cmd curl -fsSL "$BLUETUITH_ARCHIVE_URL" -o "$archive_path"
  run_cmd tar -xzf "$archive_path" -C "$tmp_dir"
  run_cmd install -m 0755 "$tmp_dir/bluetuith" "$binary_path"
  run_cmd ln -sfn "$binary_path" "$launcher_path"
  run_cmd rm -rf "$tmp_dir"
}

# Install oh-my-zsh for the current user without executing a remote installer.
install_oh_my_zsh_if_needed() {
  local install_dir="$HOME/.oh-my-zsh"
  local clone_dir

  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    log_success 'oh-my-zsh already installed'
    return 0
  fi

  if ! command -v zsh >/dev/null 2>&1; then
    log_warn 'zsh not found, skipping oh-my-zsh install'
    return 0
  fi

  if ! command -v git >/dev/null 2>&1; then
    log_warn 'git not found, skipping oh-my-zsh install'
    return 0
  fi

  log "installing oh-my-zsh from git repository: ${OH_MY_ZSH_REPO_URL} (${OH_MY_ZSH_REF})"
  clone_dir="$TEMP_DIR/oh-my-zsh"
  if is_dry_run; then
    run_cmd git init "$clone_dir"
    run_cmd git -C "$clone_dir" remote add origin "$OH_MY_ZSH_REPO_URL"
    run_cmd git -C "$clone_dir" fetch --depth=1 origin "$OH_MY_ZSH_REF"
    run_cmd git -C "$clone_dir" checkout --detach FETCH_HEAD
    run_cmd git -C "$clone_dir" rev-parse --verify HEAD
    run_cmd mv "$clone_dir" "$install_dir"
    return 0
  fi

  git init "$clone_dir"
  git -C "$clone_dir" remote add origin "$OH_MY_ZSH_REPO_URL"
  git -C "$clone_dir" fetch --depth=1 origin "$OH_MY_ZSH_REF"
  git -C "$clone_dir" checkout --detach FETCH_HEAD
  git -C "$clone_dir" rev-parse --verify HEAD >/dev/null
  mv "$clone_dir" "$install_dir"
  log_success "oh-my-zsh installed at $install_dir ($(git -C "$install_dir" rev-parse --short HEAD))"
}

# Ensure zsh loads dotfiles aliases/tooling from ~/.config/zsh.
ensure_zsh_dotfiles_sourcing() {
  local zshrc="$HOME/.zshrc"
  local marker_start='# >>> dotfiles-zsh >>>'
  local marker_end='# <<< dotfiles-zsh <<<'
  local block
  block="$(cat <<'EOT'
# >>> dotfiles-zsh >>>
[[ -f "$HOME/.config/zsh/aliases.zsh" ]] && source "$HOME/.config/zsh/aliases.zsh"
[[ -f "$HOME/.config/zsh/tools.zsh" ]] && source "$HOME/.config/zsh/tools.zsh"
# <<< dotfiles-zsh <<<
EOT
)"

  if is_dry_run; then
    [[ -f "$zshrc" ]] || run_cmd touch "$zshrc"
    if grep -Fq "$marker_start" "$zshrc" 2>/dev/null; then
      log "DRY_RUN: would replace existing dotfiles-zsh block in $zshrc"
    fi
    log "DRY_RUN: would append dotfiles-zsh block to $zshrc"
    return 0
  fi

  [[ -f "$zshrc" ]] || touch "$zshrc"

  if grep -Fq "$marker_start" "$zshrc"; then
    awk -v start="$marker_start" -v end="$marker_end" '
      $0 == start {skip=1; next}
      $0 == end {skip=0; next}
      skip == 0 {print}
    ' "$zshrc" > "${zshrc}.tmp"
    mv "${zshrc}.tmp" "$zshrc"
  fi

  printf '\n%s\n' "$block" >> "$zshrc"
  log 'ensured ~/.zshrc sources ~/.config/zsh aliases and tools'
}

# Ensure zsh is the default login shell for the current user.
ensure_default_shell_zsh() {
  local zsh_path
  zsh_path="$(command -v zsh || true)"
  if [[ -z "$zsh_path" ]]; then
    log_warn 'zsh not found, cannot set default shell'
    return 0
  fi

  local passwd_shell
  passwd_shell="$(getent passwd "$USER" | cut -d: -f7 || true)"
  if [[ "$passwd_shell" == "$zsh_path" ]]; then
    log_success "default shell already set to $zsh_path"
    return 0
  fi

  log "setting default shell to $zsh_path for user $USER (current: ${passwd_shell:-unknown})"

  if is_dry_run; then
    if command -v chsh >/dev/null 2>&1; then
      run_cmd chsh -s "$zsh_path" "$USER"
    else
      run_as_root usermod -s "$zsh_path" "$USER"
    fi
    log 'DRY_RUN: default shell would be updated; logout/login would be required'
    return 0
  fi

  # Prefer chsh for user account shell change, fallback to usermod when needed.
  if command -v chsh >/dev/null 2>&1; then
    if chsh -s "$zsh_path" "$USER" >/dev/null 2>&1; then
      log 'default shell changed using chsh'
      log 'default shell updated; logout/login is required to apply it everywhere'
      return 0
    fi
  fi

  run_as_root usermod -s "$zsh_path" "$USER"
  log 'default shell updated; logout/login is required to apply it everywhere'
}

main() {
  init_temp_dir

  # Validate host compatibility before making system changes.
  check_system_requirements
  require_cmd rpm
  ensure_no_competing_pkg_manager

  # Arrays used to keep install summary.
  TO_INSTALL=()
  SKIPPED=()
  DIRECT_PACKAGE_INSTALLS=()
  GROUP_MODIFICATIONS=()

  if is_dry_run; then
    log 'DRY_RUN=1 enabled; planned actions will be printed without changing the system'
  fi

  # Resolve distro-specific package names.
  log 'resolving package variants for swayfx, terminal, swaylock, wallpaper, clipboard, updates, and dev stack'
  local sway_pkg terminal_pkg swaylock_pkg wallpaper_pkg clipboard_pkg automatic_pkg notify_center_pkg swayosd_pkg
  local node_pkg npm_pkg docker_pkg docker_compose_pkg sysinfo_pkg fd_pkg
  enable_swayfx_copr_if_needed
  enable_swayosd_copr_if_needed
  enable_vscode_repo_if_needed
  enable_librewolf_repo_if_needed
  if ! pkg_is_available swayfx; then
    if is_dry_run; then
      log "DRY_RUN: swayfx is not currently available; assuming it would be available after enabling COPR: ${SWAYFX_COPR}"
      sway_pkg='swayfx'
    else
      if [[ "$REQUIRE_SWAYFX" == '1' ]]; then
        log_error "swayfx package is required but still unavailable after COPR enable ($SWAYFX_COPR)"
        exit 1
      fi
      log_error 'swayfx package unavailable and REQUIRE_SWAYFX=0 is unsupported in this profile'
      exit 1
    fi
  else
    sway_pkg='swayfx'
  fi
  log 'using swayfx package'
  terminal_pkg="$(resolve_pkg kitty wezterm alacritty || true)"
  if [[ -z "$terminal_pkg" ]]; then
    if is_dry_run; then
      terminal_pkg='kitty'
      log 'DRY_RUN: no terminal package currently found; planning first candidate: kitty'
    else
      log_error 'no terminal package found (expected kitty, wezterm, or alacritty)'
      exit 1
    fi
  fi
  # Keep currently installed swaylock variant to avoid COPR conflict churn.
  if pkg_is_installed swaylock; then
    swaylock_pkg='swaylock'
  elif pkg_is_installed swaylock-effects; then
    swaylock_pkg='swaylock-effects'
  else
    swaylock_pkg="$(resolve_pkg swaylock swaylock-effects || true)"
    if [[ -z "$swaylock_pkg" ]]; then
      if is_dry_run; then
        swaylock_pkg='swaylock'
        log 'DRY_RUN: no swaylock package currently found; planning first candidate: swaylock'
      else
        log_error 'no swaylock package found (expected swaylock or swaylock-effects)'
        exit 1
      fi
    fi
  fi
  wallpaper_pkg="$(resolve_pkg swww swaybg || true)"
  if [[ -z "$wallpaper_pkg" ]]; then
    if is_dry_run; then
      wallpaper_pkg='swww'
      log 'DRY_RUN: no wallpaper package currently found; planning first candidate: swww'
    else
      log_error 'no wallpaper package found (expected swww or swaybg)'
      exit 1
    fi
  fi
  clipboard_pkg="$(resolve_pkg cliphist clipman || true)"
  launcher_pkg="$(resolve_pkg fuzzel wofi rofi-wayland rofi || true)"
  automatic_pkg="$(resolve_pkg dnf5-plugin-automatic dnf-automatic || true)"
  notify_center_pkg="$(resolve_pkg swaync SwayNotificationCenter swaynotificationcenter || true)"
  swayosd_pkg="$(resolve_pkg swayosd || true)"
  node_pkg="$(resolve_pkg nodejs || true)"
  npm_pkg="$(resolve_pkg npm || true)"
  docker_pkg="$(resolve_pkg docker moby-engine docker-ce || true)"
  docker_compose_pkg="$(resolve_pkg docker-compose docker-compose-plugin || true)"
  sysinfo_pkg="$(resolve_pkg fastfetch neofetch || true)"
  fd_pkg="$(resolve_pkg fd fd-find || true)"

  # Core Wayland desktop stack.
  log 'core WM packages'
  queue_pkg "$sway_pkg"
  queue_pkg "$terminal_pkg"
  queue_pkg waybar
  if [[ -n "$launcher_pkg" ]]; then
    queue_pkg "$launcher_pkg"
  else
    log_warn 'launcher package not found (expected fuzzel/wofi/rofi), continuing without it'
  fi
  queue_pkg mako
  if [[ -n "$notify_center_pkg" ]]; then
    queue_pkg "$notify_center_pkg"
  else
    log_warn 'notification center package not found (expected swaync or swaynotificationcenter), continuing without it'
  fi
  if [[ -n "$swayosd_pkg" ]]; then
    queue_pkg "$swayosd_pkg"
  else
    log_warn 'swayosd package not found, continuing without it'
  fi
  queue_pkg wlogout
  queue_pkg brightnessctl
  queue_pkg swayidle
  queue_pkg "$swaylock_pkg"
  queue_pkg "$wallpaper_pkg"
  queue_pkg grim
  queue_pkg slurp
  queue_pkg hyprpicker
  queue_pkg jq
  queue_pkg xdg-desktop-portal
  queue_pkg xdg-desktop-portal-gtk
  queue_pkg xdg-desktop-portal-wlr
  queue_pkg bluez
  queue_pkg bluez-tools
  queue_pkg wl-clipboard
  queue_pkg wtype
  queue_pkg gnome-keyring
  queue_pkg seahorse
  queue_pkg celluloid
  if [[ -n "$clipboard_pkg" ]]; then
    queue_pkg "$clipboard_pkg"
  else
    log_warn 'clipboard history package not found (expected cliphist or clipman), continuing without it'
  fi
  queue_pkg curl
  queue_pkg unzip

  # Developer baseline packages.
  log 'developer baseline packages'
  queue_pkg nano
  queue_pkg openssh-server
  queue_pkg btop
  queue_pkg bat
  queue_pkg grep
  queue_pkg gawk
  queue_pkg sed
  queue_pkg gcc
  queue_pkg python3
  queue_pkg git
  queue_pkg git-extras
  queue_pkg tig
  queue_pkg ripgrep
  queue_pkg fzf
  queue_pkg duf
  queue_pkg zoxide
  queue_pkg atuin
  if [[ -n "$sysinfo_pkg" ]]; then
    queue_pkg "$sysinfo_pkg"
  else
    log_warn 'system info package not found (expected fastfetch or neofetch), continuing without it'
  fi
  if [[ -n "$fd_pkg" ]]; then
    queue_pkg "$fd_pkg"
  else
    log_warn 'fd package not found (expected fd or fd-find), continuing without it'
  fi
  queue_pkg zsh
  if [[ -n "$node_pkg" ]]; then
    queue_pkg "$node_pkg"
  else
    log_warn 'nodejs package not found in enabled repos'
  fi
  if [[ -n "$npm_pkg" ]]; then
    queue_pkg "$npm_pkg"
  else
    log_warn 'npm package not found as standalone package (will rely on nodejs-provided npm if available)'
  fi
  if pkg_is_available pnpm; then
    queue_pkg pnpm
  fi
  if [[ -n "$docker_pkg" ]]; then
    queue_pkg "$docker_pkg"
  else
    log_warn 'docker engine package not found (expected docker, moby-engine, or docker-ce)'
  fi
  if [[ -n "$docker_compose_pkg" ]]; then
    queue_pkg "$docker_compose_pkg"
  else
    log_warn 'docker compose package not found (expected docker-compose or docker-compose-plugin)'
  fi
  queue_pkg librewolf
  queue_pkg code
  queue_pkg thunderbird

  # Audio stack and fallback UI mixer.
  log 'audio packages'
  queue_pkg pipewire
  queue_pkg wireplumber
  queue_pkg pavucontrol

  # Network management helpers.
  log 'network packages'
  queue_pkg NetworkManager-tui

  # External disk management tools.
  log 'external disk packages'
  queue_pkg udisks2
  queue_pkg udiskie

  # Webcam tooling.
  log 'webcam packages'
  queue_pkg v4l-utils
  queue_pkg guvcview

  # Security, updates, and package manager UI tools.
  log 'updates and security packages'
  queue_pkg plasma-discover
  if [[ -n "$automatic_pkg" ]]; then
    queue_pkg "$automatic_pkg"
  else
    log_warn 'automatic updates package not found (expected dnf5-plugin-automatic or dnf-automatic)'
  fi
  queue_pkg fwupd
  queue_pkg firewalld

  # Optional virtualization packages.
  if [[ "$WITH_VIRT" == '1' ]]; then
    log 'virtualization packages enabled by WITH_VIRT=1'
    queue_pkg virt-manager
    queue_pkg libvirt
    queue_pkg qemu-kvm
  else
    log 'virtualization packages skipped (set WITH_VIRT=1 to enable)'
  fi

  # Apply installation.
  ensure_swayfx_installed_without_conflict
  install_queued
  ensure_handy_installed
  ensure_obsidian_installed
  ensure_insomnia_installed
  ensure_localsend_installed
  ensure_bluetuith_installed

  # Validate group access for brightness/video controls.
  check_video_group_membership
  check_docker_group_membership
  ensure_pnpm_installed
  install_oh_my_zsh_if_needed
  ensure_zsh_dotfiles_sourcing
  ensure_default_shell_zsh

  # Print skipped package summary.
  if [[ "${#SKIPPED[@]}" -gt 0 ]]; then
    log_warn 'some packages were skipped because unavailable in current repos:'
    printf '  - %s\n' "${SKIPPED[@]}"
  fi

  if is_dry_run; then
    local planned_package_count planned_group_count
    planned_package_count="$((${#TO_INSTALL[@]} + ${#DIRECT_PACKAGE_INSTALLS[@]}))"
    planned_group_count="${#GROUP_MODIFICATIONS[@]}"
    log "${planned_package_count} paquets seraient installés, ${planned_group_count} modifications de groupes"
  fi

  log_success 'done'
}

# Entrypoint.
main "$@"
