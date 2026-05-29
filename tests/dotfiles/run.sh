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

# shellcheck source=../../lib/log.sh
source "$ROOT_DIR/lib/log.sh"
# shellcheck source=../../modules/dotfiles/module.sh
source "$ROOT_DIR/modules/dotfiles/module.sh"

assert_manifest_contains() {
  local manifest="$1"
  local expected="$2"

  if ! grep -Fq "$expected" "$manifest"; then
    fail_test "Expected manifest entry for: $expected"
  fi
}

prepare_targets() {
  mkdir -p "$HOME/.config/waybar"
  printf 'old directory content\n' > "$HOME/.config/waybar/old.txt"
  printf 'old file content\n' > "$HOME/.config/mako"
  ln -s "$DOTFILES_SOURCE_ROOT/sway" "$HOME/.config/sway"
  ln -s "$HOME/other-target" "$HOME/.config/fuzzel"
  ln -s "$HOME/missing-target" "$HOME/.config/wofi"
}

run_dry_run_case() {
  export HOME="$TEST_HOME/dry-run-home"
  mkdir -p "$HOME/.config"
  prepare_targets

  dotfiles_plan >/dev/null

  [[ -d "$HOME/.config/waybar" ]] || {
    fail_test 'Dry-run changed existing directory.'
  }
  [[ -f "$HOME/.config/mako" ]] || {
    fail_test 'Dry-run changed existing file.'
  }
  [[ ! -e "$HOME/.config/kitty" && ! -L "$HOME/.config/kitty" ]] || {
    fail_test 'Dry-run created missing target.'
  }
  [[ ! -e "$(backup_root)" ]] || {
    fail_test 'Dry-run created backup root.'
  }
}

run_apply_case() {
  local manifest

  export HOME="$TEST_HOME/apply-home"
  mkdir -p "$HOME/.config"
  prepare_targets

  dotfiles_preflight >/dev/null
  dotfiles_apply >/dev/null

  assert_symlink_to "$HOME/.config/sway" "$DOTFILES_SOURCE_ROOT/sway"
  assert_symlink_to "$HOME/.config/waybar" "$DOTFILES_SOURCE_ROOT/waybar"
  assert_symlink_to "$HOME/.config/mako" "$DOTFILES_SOURCE_ROOT/mako"
  assert_symlink_to "$HOME/.config/fuzzel" "$DOTFILES_SOURCE_ROOT/fuzzel"
  assert_symlink_to "$HOME/.config/wofi" "$DOTFILES_SOURCE_ROOT/wofi"
  assert_symlink_to "$HOME/.config/kitty" "$DOTFILES_SOURCE_ROOT/kitty"

  manifest="$(backup_latest_batch)/manifest.tsv"
  [[ -f "$manifest" ]] || {
    fail_test "Expected backup manifest: $manifest"
  }

  assert_manifest_contains "$manifest" "$HOME/.config/waybar"
  assert_manifest_contains "$manifest" "$HOME/.config/mako"
  assert_manifest_contains "$manifest" "$HOME/.config/fuzzel"
  assert_manifest_contains "$manifest" "$HOME/.config/wofi"
  assert_manifest_contains "$manifest" "directory"
  assert_manifest_contains "$manifest" "file"
  assert_manifest_contains "$manifest" "symlink"
}

run_cli_apply_blocked_case() {
  local status=0 blocked_managed

  export HOME="$TEST_HOME/cli-home"
  mkdir -p "$HOME"

  # Inject a required non-dnf entry so packages_preflight always blocks — regardless of
  # what is installed in the test environment or available in repos.
  blocked_managed="$TEST_HOME/cli-blocked.conf"
  cat > "$blocked_managed" <<'EOF'
appimage:required-app:desktop:required:guaranteed preflight blocker for test
dnf:git:core:required:
EOF

  PACKAGES_MANAGED_FILE="$blocked_managed" \
  "$ROOT_DIR/bin/swaydora" install --profile workstation >/dev/null 2>&1 || status=$?
  if [[ "$status" -eq 0 ]]; then
    fail_test 'Workstation apply unexpectedly succeeded with required non-dnf blocker.'
  fi

  [[ ! -e "$HOME/.config/sway" && ! -L "$HOME/.config/sway" ]] || {
    fail_test 'Workstation apply created dotfiles after packages preflight failure.'
  }
}

main() {
  [[ "$HOME" == "$ORIGINAL_HOME" ]] || fail_test 'Unexpected test HOME before setup.'

  run_dry_run_case
  run_apply_case
  run_cli_apply_blocked_case
}

main "$@"
