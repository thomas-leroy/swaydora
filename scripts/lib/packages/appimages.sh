#!/usr/bin/env bash

ensure_obsidian_installed() {
  local install_dir appimage_path launcher_path

  if command -v obsidian >/dev/null 2>&1; then
    packages_info 'Obsidian already installed'
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
  packages_info "installing Obsidian from AppImage: ${OBSIDIAN_APPIMAGE_URL}"
  download_verified_sha256 "$OBSIDIAN_APPIMAGE_URL" "$OBSIDIAN_APPIMAGE_SHA256" "$appimage_path"
  run_cmd chmod +x "$appimage_path"
  run_cmd ln -sfn "$appimage_path" "$launcher_path"
  record_file_action "$appimage_path"
  record_file_action "$launcher_path -> $appimage_path"
}

ensure_localsend_installed() {
  local install_dir appimage_path launcher_path desktop_dir desktop_file

  if command -v localsend >/dev/null 2>&1 || command -v localsend_app >/dev/null 2>&1; then
    packages_info 'LocalSend already installed'
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
  packages_info "installing LocalSend from AppImage: ${LOCALSEND_APPIMAGE_URL}"
  download_verified_sha256 "$LOCALSEND_APPIMAGE_URL" "$LOCALSEND_APPIMAGE_SHA256" "$appimage_path"
  run_cmd chmod +x "$appimage_path"
  run_cmd ln -sfn "$appimage_path" "$launcher_path"
  record_file_action "$appimage_path"
  record_file_action "$launcher_path -> $appimage_path"

  if is_dry_run; then
    packages_info "DRY_RUN: would write desktop entry: $desktop_file"
    record_file_action "$desktop_file"
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
  record_file_action "$desktop_file"
}

ensure_insomnia_installed() {
  local install_dir appimage_path launcher_path desktop_dir desktop_file

  if command -v insomnia >/dev/null 2>&1; then
    packages_info 'Insomnia already installed'
    return 0
  fi

  if pkg_is_available insomnia; then
    install_pkg_now insomnia
    return 0
  fi

  install_dir="$HOME/.local/opt/insomnia"
  appimage_path="$install_dir/Insomnia.AppImage"
  launcher_path="$HOME/.local/bin/insomnia"
  desktop_dir="$HOME/.local/share/applications"
  desktop_file="$desktop_dir/insomnia.desktop"

  run_cmd mkdir -p "$install_dir" "$HOME/.local/bin" "$desktop_dir"
  packages_info "installing Insomnia from AppImage: ${INSOMNIA_APPIMAGE_URL}"
  download_verified_sha256 "$INSOMNIA_APPIMAGE_URL" "$INSOMNIA_APPIMAGE_SHA256" "$appimage_path"
  run_cmd chmod +x "$appimage_path"
  run_cmd ln -sfn "$appimage_path" "$launcher_path"
  record_file_action "$appimage_path"
  record_file_action "$launcher_path -> $appimage_path"

  if is_dry_run; then
    packages_info "DRY_RUN: would write desktop entry: $desktop_file"
    record_file_action "$desktop_file"
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
  record_file_action "$desktop_file"
}

install_appimage_apps() {
  packages_step 'Install AppImage Apps'
  ensure_obsidian_installed
  ensure_insomnia_installed
  ensure_localsend_installed
}
