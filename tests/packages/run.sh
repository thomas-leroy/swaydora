#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_HOME="$(mktemp -d)"

cleanup() {
  rm -rf "$TEST_HOME"
}

trap cleanup EXIT

# shellcheck source=../lib/assertions.sh
source "$ROOT_DIR/tests/lib/assertions.sh"

run_packages_apply() {
  SWAYDORA_TEST_MODE=1 \
  SWAYDORA_TEST_INSTALLED_DNF='git' \
  SWAYDORA_TEST_COPR_SUPPORT="${SWAYDORA_TEST_COPR_SUPPORT:-1}" \
  SWAYDORA_TEST_CONFIGURED_COPRS="${SWAYDORA_TEST_CONFIGURED_COPRS:-}" \
  SWAYDORA_TEST_UNAVAILABLE_DNF="${SWAYDORA_TEST_UNAVAILABLE_DNF:-}" \
  PACKAGES_MANAGED_FILE="$1" \
  bash -c 'source "$1"; packages_apply' bash "$ROOT_DIR/modules/packages/module.sh"
}

run_packages_plan() {
  SWAYDORA_TEST_MODE=1 \
  SWAYDORA_TEST_INSTALLED_DNF='git' \
  SWAYDORA_TEST_COPR_SUPPORT="${SWAYDORA_TEST_COPR_SUPPORT:-1}" \
  SWAYDORA_TEST_CONFIGURED_COPRS="${SWAYDORA_TEST_CONFIGURED_COPRS:-}" \
  SWAYDORA_TEST_UNAVAILABLE_DNF="${SWAYDORA_TEST_UNAVAILABLE_DNF:-}" \
  PACKAGES_MANAGED_FILE="$1" \
  bash -c 'source "$1"; packages_plan' bash "$ROOT_DIR/modules/packages/module.sh"
}

write_inventory() {
  local path="$1"

  cat > "$path" <<'EOF'
# comment line

dnf:git:core:required:
dnf:kitty:desktop:required:
dnf-optional:pnpm:dev:optional:
appimage:obsidian:desktop:desired:
manual:oh-my-zsh:shell:manual:
unsupported:user-groups:post-install:unsupported:
EOF
}

write_blocked_inventory() {
  local path="$1"

  cat > "$path" <<'EOF'
dnf:kitty:desktop:required:
appimage:obsidian:desktop:required:needed before strict full install
appimage:insomnia:desktop:required:needed before strict full install
appimage:localsend:desktop:required:needed before strict full install
EOF
}

write_copr_inventory() {
  local path="$1"

  cat > "$path" <<'EOF'
copr:swayfx/swayfx:desktop:required:required for swayfx package
manual:syshud:desktop:desired:transitional manual HUD replacement
dnf:kitty:desktop:required:
EOF
}

write_unknown_copr_inventory() {
  local path="$1"

  cat > "$path" <<'EOF'
copr:example/unknown:desktop:required:not allowed for enablement
dnf:kitty:desktop:required:
EOF
}

write_unavailable_desired_inventory() {
  local path="$1"

  cat > "$path" <<'EOF'
dnf:git:core:required:
dnf:kitty:desktop:desired:
dnf:swww:desktop:desired:
EOF
}

write_unavailable_required_inventory() {
  local path="$1"

  cat > "$path" <<'EOF'
dnf:git:core:required:
dnf:swww:desktop:desired:
dnf:hyprpicker:desktop:required:
EOF
}

write_replacement_inventory() {
  local path="$1"

  cat > "$path" <<'EOF'
dnf:swayfx:desktop:required:preferred sway compositor
dnf:kitty:desktop:required:preferred terminal
EOF
}

main() {
  local inventory blocked_inventory copr_inventory unknown_copr_inventory output blocked_output copr_output plugin_output failed_enable_output unknown_output status=0
  local unavail_desired_inventory unavail_required_inventory replacement_inventory avail_output unavail_desired_output unavail_required_output replacement_output

  inventory="$TEST_HOME/managed.conf"
  blocked_inventory="$TEST_HOME/blocked.conf"
  copr_inventory="$TEST_HOME/copr.conf"
  unknown_copr_inventory="$TEST_HOME/unknown-copr.conf"
  unavail_desired_inventory="$TEST_HOME/unavail-desired.conf"
  unavail_required_inventory="$TEST_HOME/unavail-required.conf"
  replacement_inventory="$TEST_HOME/replacement.conf"
  write_inventory "$inventory"
  write_blocked_inventory "$blocked_inventory"
  write_copr_inventory "$copr_inventory"
  write_unknown_copr_inventory "$unknown_copr_inventory"
  write_unavailable_desired_inventory "$unavail_desired_inventory"
  write_unavailable_required_inventory "$unavail_required_inventory"
  write_replacement_inventory "$replacement_inventory"

  output="$(run_packages_plan "$inventory")"
  grep -Fq '[OK] Installed dnf package: git' <<<"$output" || fail_test 'Expected installed dnf package in plan.'
  grep -Fq '[PLAN] Required dnf package missing: kitty' <<<"$output" || fail_test 'Expected missing required dnf package in plan.'
  grep -Fq 'Desired AppImage not implemented: obsidian' <<<"$output" || fail_test 'Expected desired AppImage warning in plan.'
  grep -Fq 'Manual post-install action: oh-my-zsh' <<<"$output" || fail_test 'Expected manual action in plan.'
  grep -Fq 'Unsupported package-side action not automated yet: user-groups' <<<"$output" || fail_test 'Expected unsupported entry warning in plan.'
  grep -Fq '[INFO] Package summary:' <<<"$output" || fail_test 'Expected package summary.'
  grep -Fq '[INFO] - required missing dnf packages: 1' <<<"$output" || fail_test 'Expected required missing summary.'
  grep -Fq '[INFO] - desired unavailable: 1' <<<"$output" || fail_test 'Expected desired unavailable summary.'
  grep -Fq '[INFO] - optional missing: 1' <<<"$output" || fail_test 'Expected optional missing summary.'
  grep -Fq '[INFO] - manual actions: 1' <<<"$output" || fail_test 'Expected manual action summary.'
  grep -Fq '[INFO] - unsupported actions: 1' <<<"$output" || fail_test 'Expected unsupported action summary.'

  output="$(run_packages_apply "$inventory")"
  grep -Fq '[INFO] Installing dnf packages: kitty' <<<"$output" || fail_test 'Expected dnf install log.'
  grep -Fq 'sudo dnf install -y kitty' <<<"$output" || fail_test 'Expected captured dnf command intent.'
  grep -Fq 'Skipping non-dnf package category during apply: appimage:obsidian' <<<"$output" || fail_test 'Expected non-dnf skip warning.'
  if grep -Fq '[PLAN] Would install dnf packages' <<<"$output"; then
    fail_test 'Non-dry-run output must not contain [PLAN] Would install dnf packages.'
  fi

  # Dry-run must still emit [PLAN] lines for missing packages.
  output="$(run_packages_plan "$inventory")"
  grep -Fq '[PLAN]' <<<"$output" || fail_test 'Expected [PLAN] lines in dry-run output.'

  blocked_output="$(run_packages_apply "$blocked_inventory" 2>&1)" || status=$?
  if [[ "$status" -eq 0 ]]; then
    fail_test 'Required non-dnf blocker unexpectedly passed.'
  fi
  grep -Fq '[INFO] Preflighting package apply' <<<"$blocked_output" || fail_test 'Expected package apply preflight log.'
  grep -Fq 'Cannot apply packages while required non-dnf entries are not implemented' <<<"$blocked_output" || fail_test 'Expected required non-dnf blocker error.'
  grep -Fq '[ERROR] - appimage:obsidian [desktop]' <<<"$blocked_output" || fail_test 'Expected obsidian blocker.'
  grep -Fq '[ERROR] - appimage:insomnia [desktop]' <<<"$blocked_output" || fail_test 'Expected insomnia blocker.'
  grep -Fq '[ERROR] - appimage:localsend [desktop]' <<<"$blocked_output" || fail_test 'Expected localsend blocker.'
  if grep -Fq 'Applying dnf package inventory' <<<"$blocked_output"; then
    fail_test 'Blocked apply entered dnf apply phase.'
  fi
  if grep -Fq 'Skipping non-dnf package category during apply' <<<"$blocked_output"; then
    fail_test 'Blocked apply logged non-dnf apply skips.'
  fi
  if grep -Fq 'sudo dnf install -y' <<<"$blocked_output"; then
    fail_test 'Blocked apply attempted dnf install command.'
  fi

  output="$(run_packages_plan "$copr_inventory")"
  grep -Fq '[INFO] dnf copr support package installed: dnf-plugins-core' <<<"$output" || fail_test 'Expected COPR support package report.'
  grep -Fq '[PLAN] Required COPR missing: swayfx/swayfx' <<<"$output" || fail_test 'Expected missing swayfx COPR plan.'
  grep -Fq '[PLAN] Would enable required COPR: swayfx/swayfx' <<<"$output" || fail_test 'Expected swayfx COPR enable plan.'
  grep -Fq 'Manual post-install action: syshud' <<<"$output" || fail_test 'Expected syshud manual action.'
  grep -Fq '[INFO] - required missing COPRs: 1' <<<"$output" || fail_test 'Expected missing COPR summary.'
  if grep -Fq 'erikreider/swayosd' <<<"$output"; then
    fail_test 'Unexpected swayosd COPR plan.'
  fi

  status=0
  copr_output="$(run_packages_apply "$copr_inventory" 2>&1)" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail_test 'Missing required COPRs should be enabled in test mode.'
  fi
  grep -Fq '[INFO] Enabling required COPR: swayfx/swayfx' <<<"$copr_output" || fail_test 'Expected swayfx COPR enable log.'
  grep -Fq 'sudo dnf copr enable -y swayfx/swayfx' <<<"$copr_output" || fail_test 'Expected swayfx COPR enable command intent.'
  grep -Fq '[OK] Enabled COPR: swayfx/swayfx' <<<"$copr_output" || fail_test 'Expected swayfx COPR success log.'
  if grep -Fq 'erikreider/swayosd' <<<"$copr_output"; then
    fail_test 'Unexpected swayosd COPR enablement.'
  fi
  if [[ "$copr_output" != *"sudo dnf copr enable -y swayfx/swayfx"*"sudo dnf install -y kitty"* ]]; then
    fail_test 'DNF install did not occur after COPR enablement.'
  fi

  status=0
  plugin_output="$(
    SWAYDORA_TEST_COPR_SUPPORT=0 \
    SWAYDORA_TEST_CONFIGURED_COPRS='swayfx/swayfx' \
    run_packages_apply "$copr_inventory" 2>&1
  )" || status=$?
  if [[ "$status" -eq 0 ]]; then
    fail_test 'Missing COPR support unexpectedly passed.'
  fi
  grep -Fq '[ERROR] Missing COPR support package: dnf-plugins-core' <<<"$plugin_output" || fail_test 'Expected missing COPR support error.'
  if grep -Fq 'sudo dnf install -y' <<<"$plugin_output"; then
    fail_test 'Missing COPR support attempted dnf install command.'
  fi

  status=0
  failed_enable_output="$(
    SWAYDORA_TEST_COPR_ENABLE_FAIL=1 \
    run_packages_apply "$copr_inventory" 2>&1
  )" || status=$?
  if [[ "$status" -eq 0 ]]; then
    fail_test 'Failed COPR enable unexpectedly passed.'
  fi
  grep -Fq '[ERROR] Failed to enable COPR: swayfx/swayfx' <<<"$failed_enable_output" || fail_test 'Expected failed COPR enable error.'
  if grep -Fq 'sudo dnf install -y' <<<"$failed_enable_output"; then
    fail_test 'Failed COPR enable attempted dnf install command.'
  fi

  status=0
  unknown_output="$(run_packages_apply "$unknown_copr_inventory" 2>&1)" || status=$?
  if [[ "$status" -eq 0 ]]; then
    fail_test 'Unknown required COPR unexpectedly passed.'
  fi
  grep -Fq 'unknown required COPR: example/unknown [desktop]' <<<"$unknown_output" || fail_test 'Expected unknown COPR blocker.'
  if grep -Fq 'sudo dnf copr enable -y example/unknown' <<<"$unknown_output"; then
    fail_test 'Unknown COPR was enabled.'
  fi

  # --- Availability preflight tests ---

  # Unavailable desired package: skipped with warning, apply succeeds.
  status=0
  avail_output="$(
    SWAYDORA_TEST_UNAVAILABLE_DNF='swww' \
    run_packages_apply "$unavail_desired_inventory" 2>&1
  )" || status=$?
  if [[ "$status" -ne 0 ]]; then
    fail_test 'Unavailable desired dnf package must not block apply.'
  fi

  # Availability check must have run.
  grep -Fq '[INFO] Checking dnf package availability' <<<"$avail_output" || fail_test 'Expected availability check log.'
  grep -Fq '[WARN] Desired dnf package unavailable, skipping: swww' <<<"$avail_output" || fail_test 'Expected warning for unavailable desired package.'

  # Unavailable desired package absent from final install array (reflected in log).
  install_log_line="$(grep '\[INFO\] Installing dnf packages:' <<<"$avail_output" || true)"
  [[ -n "$install_log_line" ]] || fail_test 'Expected [INFO] Installing dnf packages log line.'
  if grep -Fq 'swww' <<<"$install_log_line"; then
    fail_test 'Unavailable desired package must not appear in install log (PACKAGES_APPLY_DNF leaked).'
  fi

  # Unavailable desired package absent from install command.
  if grep -Fq 'swww' <<<"$(grep 'sudo dnf install' <<<"$avail_output")"; then
    fail_test 'Unavailable desired package must not appear in install command.'
  fi

  # Available desired package still installed.
  grep -Fq 'kitty' <<<"$install_log_line" || fail_test 'Available desired package must appear in install log.'
  grep -Fq 'sudo dnf install -y kitty' <<<"$avail_output" || fail_test 'Available desired package must appear in install command.'

  # Dry-run still shows planned install lines for the same inventory (no availability check in plan).
  dry_run_output="$(run_packages_plan "$unavail_desired_inventory")"
  grep -Fq '[PLAN] Would install desired dnf package: kitty' <<<"$dry_run_output" || fail_test 'Expected [PLAN] Would install desired dnf package in dry-run.'
  grep -Fq '[PLAN] Would install desired dnf package: swww' <<<"$dry_run_output" || fail_test 'Expected swww in dry-run plan (plan does not filter availability).'
  if grep -Fq '[PLAN] Would install dnf packages' <<<"$dry_run_output"; then
    fail_test 'Dry-run must not emit the bulk [PLAN] Would install dnf packages line.'
  fi

  # Unavailable required package: blocks apply before install.
  status=0
  unavail_required_output="$(
    SWAYDORA_TEST_UNAVAILABLE_DNF='hyprpicker swww' \
    run_packages_apply "$unavail_required_inventory" 2>&1
  )" || status=$?
  if [[ "$status" -eq 0 ]]; then
    fail_test 'Unavailable required dnf package must block apply.'
  fi
  grep -Fq '[ERROR] Unavailable required dnf packages block install:' <<<"$unavail_required_output" || fail_test 'Expected error for unavailable required package.'
  grep -Fq '[ERROR] - hyprpicker' <<<"$unavail_required_output" || fail_test 'Expected hyprpicker listed as blocker.'
  if grep -Fq 'sudo dnf install -y' <<<"$unavail_required_output"; then
    fail_test 'Unavailable required package must prevent install command.'
  fi
  if grep -Fq '[INFO] Installing dnf packages:' <<<"$unavail_required_output"; then
    fail_test 'Unavailable required package must prevent install log line.'
  fi

  # Unavailable desired package warning still shown even when required blocks.
  grep -Fq '[WARN] Desired dnf package unavailable, skipping: swww' <<<"$unavail_required_output" || fail_test 'Expected warning for unavailable desired package alongside required blocker.'

  # Fedora Sway Spin ships sway, and swayfx replaces it. Keep --allowerasing
  # scoped to the known replacement package instead of applying it globally.
  replacement_output="$(run_packages_apply "$replacement_inventory" 2>&1)"
  grep -Fq '[INFO] Installing dnf packages: kitty' <<<"$replacement_output" || fail_test 'Expected normal dnf install log for kitty.'
  grep -Fq 'sudo dnf install -y kitty' <<<"$replacement_output" || fail_test 'Expected normal dnf command for kitty.'
  grep -Fq '[INFO] Installing dnf replacement packages with --allowerasing: swayfx' <<<"$replacement_output" || fail_test 'Expected allowerasing install log for swayfx.'
  grep -Fq 'sudo dnf install -y --allowerasing swayfx' <<<"$replacement_output" || fail_test 'Expected allowerasing command for swayfx.'
  if grep -Fq 'sudo dnf install -y --allowerasing swayfx kitty' <<<"$replacement_output"; then
    fail_test '--allowerasing must not be applied to the whole package batch.'
  fi
}

main "$@"
