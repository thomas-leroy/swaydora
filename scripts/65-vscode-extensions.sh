#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib/logging.sh"
setup_logger vscode-extensions
EXTENSIONS_FILE="${EXTENSIONS_FILE:-$REPO_ROOT/dotfiles/vscode/extensions.list}"
CODE_BIN="${CODE_BIN:-code}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    log_error "missing required command: $1"
    exit 1
  }
}

main() {
  require_cmd "$CODE_BIN"
  [[ -f "$EXTENSIONS_FILE" ]] || {
    log_error "extensions list not found: $EXTENSIONS_FILE"
    exit 1
  }

  local extension
  local -i total=0

  while IFS= read -r extension || [[ -n "$extension" ]]; do
    [[ -n "$extension" ]] || continue
    [[ "$extension" == \#* ]] && continue
    total+=1
    log "installing: $extension"
    "$CODE_BIN" --install-extension "$extension"
  done < "$EXTENSIONS_FILE"

  log_success "done (${total} extension(s) processed)"
}

main "$@"
