#!/usr/bin/env bash
set -euo pipefail

path_display_home() {
  local path="$1"

  printf '~%s\n' "${path#"$HOME"}"
}

path_under_dir() {
  local path="$1"
  local root="$2"

  case "$path" in
    "$root"/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}
