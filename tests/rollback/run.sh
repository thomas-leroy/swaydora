#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ORIGINAL_HOME="$HOME"

# shellcheck source=../lib/home.sh
source "$ROOT_DIR/tests/lib/home.sh"
# shellcheck source=../lib/assertions.sh
source "$ROOT_DIR/tests/lib/assertions.sh"

TEST_HOME="$(create_test_home)"
trap 'cleanup_test_home "$TEST_HOME"' EXIT

export HOME="$TEST_HOME"

# shellcheck source=../../lib/backup.sh
source "$ROOT_DIR/lib/backup.sh"

run_cli_rollback() {
  "$ROOT_DIR/bin/swaydora" rollback "$@"
}

prepare_restore_batch() {
  local batch

  mkdir -p "$HOME/.config/demo-dir"
  printf 'original file' > "$HOME/.config/demo-file"
  printf 'original nested' > "$HOME/.config/demo-dir/nested"
  printf 'original link target' > "$HOME/link-original"
  ln -s "$HOME/link-original" "$HOME/.config/demo-link"

  batch="$(backup_create_batch)"
  backup_copy_path "$batch" "$HOME/.config/demo-file"
  backup_copy_path "$batch" "$HOME/.config/demo-dir"
  backup_copy_path "$batch" "$HOME/.config/demo-link"
  printf '%s\n' "$batch"
}

mutate_targets() {
  rm -rf -- "$HOME/.config/demo-file" "$HOME/.config/demo-dir" "$HOME/.config/demo-link"
  mkdir -p "$HOME/.config/demo-dir"
  printf 'current file' > "$HOME/.config/demo-file"
  printf 'current nested' > "$HOME/.config/demo-dir/nested"
  printf 'current link target' > "$HOME/link-current"
  ln -s "$HOME/link-current" "$HOME/.config/demo-link"
}

run_restore_case() {
  local original_batch pre_batch manifest

  original_batch="$(prepare_restore_batch)"
  mutate_targets

  run_cli_rollback --dry-run >/dev/null
  assert_file_content "$HOME/.config/demo-file" 'current file'
  assert_file_content "$HOME/.config/demo-dir/nested" 'current nested'
  assert_symlink_to "$HOME/.config/demo-link" "$HOME/link-current"

  run_cli_rollback --yes >/dev/null

  assert_file_content "$HOME/.config/demo-file" 'original file'
  assert_file_content "$HOME/.config/demo-dir/nested" 'original nested'
  assert_symlink_to "$HOME/.config/demo-link" "$HOME/link-original"

  pre_batch="$(backup_latest_batch)"
  if [[ "$pre_batch" == "$original_batch" ]]; then
    fail_test 'Expected a pre-rollback backup batch.'
  fi

  manifest="$pre_batch/manifest.tsv"
  assert_manifest_count "$manifest" 3
  grep -Fq "$HOME/.config/demo-file" "$manifest"
  grep -Fq "$HOME/.config/demo-dir" "$manifest"
  grep -Fq "$HOME/.config/demo-link" "$manifest"
}

run_malformed_manifest_case() {
  local case_home batch status=0

  case_home="$TEST_HOME/malformed-home"
  export HOME="$case_home"
  mkdir -p "$HOME/.config" "$HOME/backup-source"
  printf 'safe' > "$HOME/.config/demo-file"

  batch="$(backup_create_batch)"
  printf 'bad\tmanifest\n' > "$batch/manifest.tsv"

  run_cli_rollback --dry-run >/dev/null 2>&1 || status=$?
  if [[ "$status" -eq 0 ]]; then
    fail_test 'Malformed manifest unexpectedly succeeded.'
  fi

  assert_file_content "$HOME/.config/demo-file" 'safe'
}

run_unsafe_manifest_case() {
  local case_home batch backup_path status=0

  case_home="$TEST_HOME/unsafe-home"
  export HOME="$case_home"
  mkdir -p "$HOME/.config"
  printf 'safe' > "$HOME/.config/demo-file"

  batch="$(backup_create_batch)"
  mkdir -p "$batch/files/tmp"
  backup_path="$batch/files/tmp/outside"
  printf 'outside' > "$backup_path"
  printf '/tmp/outside\t%s\tfile\t2026-05-25T00:00:00+0000\n' "$backup_path" > "$batch/manifest.tsv"

  run_cli_rollback --dry-run >/dev/null 2>&1 || status=$?
  if [[ "$status" -eq 0 ]]; then
    fail_test 'Unsafe manifest unexpectedly succeeded.'
  fi

  assert_file_content "$HOME/.config/demo-file" 'safe'
}

main() {
  assert_home_isolated "$ORIGINAL_HOME"

  run_restore_case
  run_malformed_manifest_case
  run_unsafe_manifest_case
}

main "$@"
