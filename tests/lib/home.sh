#!/usr/bin/env bash
set -euo pipefail

create_test_home() {
  mktemp -d
}

cleanup_test_home() {
  local test_home="$1"

  [[ -n "$test_home" ]] || return 0
  rm -rf "$test_home"
}

assert_home_isolated() {
  local original_home="$1"

  [[ "$HOME" != "$original_home" ]] || {
    printf 'Test HOME was not isolated.\n' >&2
    exit 1
  }
}
