#!/usr/bin/env bash
set -euo pipefail

fail_test() {
  local message="$1"

  printf '%s\n' "$message" >&2
  exit 1
}

assert_path_exists() {
  local path="$1"

  [[ -e "$path" || -L "$path" ]] || fail_test "Expected path to exist: $path"
}

assert_file_contains() {
  local path="$1"
  local expected="$2"

  grep -Fq "$expected" "$path" || fail_test "Expected $path to contain: $expected"
}

assert_file_content() {
  local path="$1"
  local expected="$2"
  local actual

  actual="$(cat "$path")"
  [[ "$actual" == "$expected" ]] || fail_test "Expected $path to contain $expected, got $actual"
}

assert_manifest_count() {
  local manifest="$1"
  local expected="$2"
  local actual

  actual="$(wc -l < "$manifest")"
  [[ "$actual" == "$expected" ]] || fail_test "Expected $expected manifest entries, got $actual"
}

assert_symlink_to() {
  local path="$1"
  local expected="$2"
  local actual

  [[ -L "$path" ]] || fail_test "Expected symlink: $path"

  actual="$(readlink "$path")"
  [[ "$actual" == "$expected" ]] || fail_test "Expected $path -> $expected, got $actual"
}
