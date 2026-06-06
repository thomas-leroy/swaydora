#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CONTAINER_NAME="${SWAYDORA_FEDORA44_CONTAINER:-swaydora-fedora-44-sway}"
CONTAINER_IMAGE="${SWAYDORA_FEDORA44_IMAGE:-registry.fedoraproject.org/fedora-toolbox:44}"

print_help() {
  cat <<EOF
Usage:
  tests/distrobox/fedora-44-sway/host.sh [--create] [--enter] [--install]

Options:
  --create  Create the Fedora 44 Distrobox when it does not exist.
  --enter   Enter the Fedora 44 Distrobox after creation/checks.
  --install Run the real workstation install inside the container.

Environment:
  SWAYDORA_FEDORA44_CONTAINER  Override container name.
  SWAYDORA_FEDORA44_IMAGE      Override Fedora 44 image.

Default behavior is read-only: print the required Distrobox commands.
EOF
}

container_exists() {
  distrobox list --no-color 2>/dev/null | grep -Fq "$CONTAINER_NAME"
}

print_plan() {
  printf 'Fedora 44 Distrobox test target\n\n'
  printf 'Container: %s\n' "$CONTAINER_NAME"
  printf 'Image:     %s\n\n' "$CONTAINER_IMAGE"
  printf 'Create explicitly with:\n'
  printf '  %s --create\n\n' "$0"
  printf 'Run validation with:\n'
  printf '  distrobox enter %s -- ./tests/distrobox/fedora-44-sway/run.sh\n' "$CONTAINER_NAME"
  printf '\nRun real install in the container with:\n'
  printf '  distrobox enter %s -- ./tests/distrobox/fedora-44-sway/install.sh --yes\n' "$CONTAINER_NAME"
}

create_container() {
  if container_exists; then
    printf 'Container already exists: %s\n' "$CONTAINER_NAME"
    return 0
  fi

  distrobox create \
    --name "$CONTAINER_NAME" \
    --image "$CONTAINER_IMAGE"
}

main() {
  local create=0
  local enter=0
  local install=0

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --create)
        create=1
        shift
        ;;
      --enter)
        enter=1
        shift
        ;;
      --install)
        install=1
        shift
        ;;
      -h|--help)
        print_help
        return 0
        ;;
      *)
        printf 'Unsupported option: %s\n\n' "$1" >&2
        print_help >&2
        return 2
        ;;
    esac
  done

  cd "$ROOT_DIR"

  if [[ "$create" -eq 0 && "$install" -eq 0 ]]; then
    print_plan
    return 0
  fi

  if [[ "$create" -eq 1 ]]; then
    create_container
  fi

  if [[ "$enter" -eq 1 ]]; then
    distrobox enter "$CONTAINER_NAME" -- ./tests/distrobox/fedora-44-sway/run.sh
  fi

  if [[ "$install" -eq 1 ]]; then
    distrobox enter "$CONTAINER_NAME" -- ./tests/distrobox/fedora-44-sway/install.sh --yes
  fi
}

main "$@"
