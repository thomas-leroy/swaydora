#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib/logging.sh"
setup_logger vscode-prefs
VSCODE_DIR="${VSCODE_DIR:-$REPO_ROOT/dotfiles/vscode}"
WRAPPER_SRC="$VSCODE_DIR/code"
SETTINGS_SRC="$VSCODE_DIR/settings.json"
LOCAL_BIN_DIR="$HOME/.local/bin"
LOCAL_CODE="$LOCAL_BIN_DIR/code"
APPLICATIONS_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$APPLICATIONS_DIR/code.desktop"
CODE_USER_DIR="$HOME/.config/Code/User"
SETTINGS_DST="$CODE_USER_DIR/settings.json"
WRITTEN_FILES=()

main() {
  [[ -x "$WRAPPER_SRC" ]] || {
    log_error "wrapper not found or not executable: $WRAPPER_SRC"
    exit 1
  }
  [[ -f "$SETTINGS_SRC" ]] || {
    log_error "settings file not found: $SETTINGS_SRC"
    exit 1
  }

  mkdir -p "$LOCAL_BIN_DIR" "$APPLICATIONS_DIR" "$CODE_USER_DIR"

  log "linking wrapper: $LOCAL_CODE -> $WRAPPER_SRC"
  ln -sfn "$WRAPPER_SRC" "$LOCAL_CODE"
  WRITTEN_FILES+=("$LOCAL_CODE -> $WRAPPER_SRC")

  log "writing desktop override: $DESKTOP_FILE"
  cat > "$DESKTOP_FILE" <<EOT
[Desktop Entry]
Name=Visual Studio Code
Comment=Code Editing. Redefined.
GenericName=Text Editor
Exec=$LOCAL_CODE %F
Icon=vscode
Type=Application
StartupNotify=false
StartupWMClass=Code
Categories=TextEditor;Development;IDE;
MimeType=application/x-code-workspace;
Actions=new-empty-window;
Keywords=vscode;

[Desktop Action new-empty-window]
Name=New Empty Window
Exec=$LOCAL_CODE --new-window %F
Icon=vscode
EOT
  WRITTEN_FILES+=("$DESKTOP_FILE")

  log "copying settings: $SETTINGS_DST"
  cp "$SETTINGS_SRC" "$SETTINGS_DST"
  WRITTEN_FILES+=("$SETTINGS_DST")

  log 'summary:'
  log "files written/linked: ${#WRITTEN_FILES[@]}"
  printf '  - %s\n' "${WRITTEN_FILES[@]}"
  log_success 'done'
}

main "$@"
