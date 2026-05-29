#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

cd "$ROOT_DIR"

log_step() {
  printf '\n== %s ==\n' "$*"
}

inside_distrobox() {
  [[ -n "${DISTROBOX_ENTER_PATH:-}" ]] && return 0
  [[ -n "${CONTAINER_ID:-}" ]] && return 0
  [[ -f /run/.containerenv ]] && return 0
  [[ -f /.dockerenv ]] && return 0
  return 1
}

collect_bash_files() {
  printf '%s\n' bin/swaydora
  find lib modules profiles tests scripts dotfiles/scripts \
    -type f \
    \( -name '*.sh' -o -name '*.bash' \) \
    -print
}

run_doctor_check() {
  local doctor_status=0

  bin/swaydora doctor || doctor_status=$?
  case "$doctor_status" in
    0|1|2)
      printf 'doctor completed with accepted status: %s\n' "$doctor_status"
      ;;
    *)
      printf 'Unexpected doctor exit code: %s\n' "$doctor_status" >&2
      return "$doctor_status"
      ;;
  esac
}

main() {
  local -a bash_files=()

  log_step 'Environment'
  if inside_distrobox; then
    printf 'Distrobox/container environment detected.\n'
  else
    printf 'Warning: Distrobox/container environment not detected; continuing read-only checks.\n'
  fi

  log_step 'Bash syntax'
  mapfile -t bash_files < <(collect_bash_files | sort -u)
  bash -n "${bash_files[@]}"

  log_step 'CLI basics'
  bin/swaydora help
  bin/swaydora version

  log_step 'Doctor'
  run_doctor_check

  log_step 'Smoke test'
  tests/smoke/run.sh
}

main "$@"
