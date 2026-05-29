#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

cd "$ROOT_DIR"

bash -n \
  bin/swaydora \
  lib/log.sh \
  lib/path.sh \
  lib/command.sh \
  lib/os.sh \
  lib/git.sh \
  lib/doctor.sh \
  lib/backup.sh \
  modules/bootstrap/module.sh \
  modules/dotfiles/module.sh \
  modules/packages/module.sh \
  profiles/minimal/profile.conf \
  profiles/workstation/profile.conf \
  dotfiles/scripts/wallpaper_picker.sh \
  dotfiles/scripts/wallpaper_start.sh \
  tests/smoke/run.sh \
  tests/backup/run.sh \
  tests/packages/run.sh \
  tests/dotfiles/run.sh \
  tests/rollback/run.sh

tests/backup/run.sh
tests/packages/run.sh
tests/dotfiles/run.sh
tests/rollback/run.sh

bash -c 'source modules/packages/module.sh; packages_check >/dev/null'

[[ -x dotfiles/scripts/audio_mixer_popup.sh ]]
if find dotfiles/scripts -type f ! -perm -111 | grep -q .; then
  printf 'Found non-executable runtime scripts in dotfiles/scripts.\n' >&2
  exit 1
fi

bin/swaydora help
bin/swaydora version
bin/swaydora install --profile minimal --dry-run
bin/swaydora install --dry-run
workstation_plan="$(bin/swaydora install --profile workstation --dry-run)"
printf '%s\n' "$workstation_plan"
grep -Fq '[INFO] Planning package inventory' <<<"$workstation_plan"
grep -Fq 'Package category: dnf' <<<"$workstation_plan"
grep -Fq 'Package category: copr' <<<"$workstation_plan"
grep -Fq 'Package category: appimage' <<<"$workstation_plan"
grep -Eq 'Installed dnf package: blueman \[desktop\]|Required dnf package missing: blueman \[desktop\]' <<<"$workstation_plan"
grep -Fq 'nm-connection-editor' <<<"$workstation_plan"
grep -Fq 'kscreen' <<<"$workstation_plan"
grep -Fq 'systemsettings' <<<"$workstation_plan"
grep -Fq 'xdg-desktop-portal-kde' <<<"$workstation_plan"
grep -Fq 'Manual post-install action:' <<<"$workstation_plan"
grep -Fq 'Manual post-install action: syshud' <<<"$workstation_plan"
grep -Fq 'Unsupported package-side action not automated yet:' <<<"$workstation_plan"
grep -Fq '[INFO] Package summary:' <<<"$workstation_plan"
grep -Fq '[INFO] - required missing COPRs:' <<<"$workstation_plan"
grep -Eq 'Installed dnf package: wiremix \[desktop\]|Required dnf package missing: wiremix \[desktop\]' <<<"$workstation_plan"
grep -Fq 'dnf:blueman:desktop:required:Bluetooth graphical manager' modules/packages/managed.conf
grep -Fq 'blueman-manager' dotfiles/scripts/bluetooth_tui.sh
if grep -Fq 'archive:bluetuith' modules/packages/managed.conf; then
  printf 'Unexpected legacy bluetuith archive entry in modular package inventory.\n' >&2
  exit 1
fi
if grep -Fq 'erikreider/swayosd' <<<"$workstation_plan"; then
  printf 'Unexpected swayosd COPR in workstation plan.\n' >&2
  exit 1
fi

wiremix_plan="$(env \
  SWAYDORA_TEST_MODE=1 \
  SWAYDORA_TEST_INSTALLED_DNF='' \
  SWAYDORA_TEST_CONFIGURED_COPRS='swayfx/swayfx' \
  PACKAGES_MANAGED_FILE="$ROOT_DIR/tests/tmp-wiremix-managed.conf" \
  bash -c 'source modules/packages/module.sh; packages_plan')"
grep -Fq '[PLAN] Required dnf package missing: wiremix [desktop]' <<<"$wiremix_plan"

doctor_status=0
bin/swaydora doctor || doctor_status=$?

case "$doctor_status" in
  0|1|2)
    exit 0
    ;;
  *)
    printf 'Unexpected doctor exit code: %s\n' "$doctor_status" >&2
    exit "$doctor_status"
    ;;
esac
