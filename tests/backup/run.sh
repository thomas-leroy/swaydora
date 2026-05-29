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

main() {
  local sample_root batch manifest
  local sample_file sample_dir sample_symlink missing_path
  local backup_file backup_dir backup_symlink
  local latest_batch

  sample_root="$HOME/samples"
  sample_file="$sample_root/config.txt"
  sample_dir="$sample_root/config-dir"
  sample_symlink="$sample_root/config-link"
  missing_path="$sample_root/missing.conf"

  mkdir -p "$sample_dir"
  printf 'sample file\n' > "$sample_file"
  printf 'nested file\n' > "$sample_dir/nested.txt"
  ln -s "$sample_file" "$sample_symlink"

  batch="$(backup_create_batch)"
  manifest="$batch/manifest.tsv"

  backup_copy_path "$batch" "$sample_file"
  backup_copy_path "$batch" "$sample_dir"
  backup_copy_path "$batch" "$sample_symlink"
  backup_copy_path "$batch" "$missing_path" >/dev/null

  backup_file="$(backup_path_for "$batch" "$sample_file")"
  backup_dir="$(backup_path_for "$batch" "$sample_dir")"
  backup_symlink="$(backup_path_for "$batch" "$sample_symlink")"

  assert_path_exists "$manifest"
  assert_path_exists "$backup_file"
  assert_path_exists "$backup_dir/nested.txt"
  assert_path_exists "$backup_symlink"

  if [[ ! -L "$backup_symlink" ]]; then
    fail_test "Expected backup to preserve symlink: $backup_symlink"
  fi

  assert_file_contains "$sample_file" 'sample file'
  assert_file_contains "$sample_dir/nested.txt" 'nested file'
  assert_manifest_count "$manifest" 3
  assert_file_contains "$manifest" "$sample_file"
  assert_file_contains "$manifest" "$sample_dir"
  assert_file_contains "$manifest" "$sample_symlink"
  assert_file_contains "$manifest" "$(backup_root)"

  latest_batch="$(backup_latest_batch)"
  if [[ "$latest_batch" != "$batch" ]]; then
    fail_test "Expected latest backup batch $batch, got $latest_batch"
  fi

  assert_home_isolated "$ORIGINAL_HOME"
}

main "$@"
