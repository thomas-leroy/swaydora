#!/usr/bin/env bash
set -euo pipefail

command -v gnome-keyring-daemon >/dev/null 2>&1 || exit 0

daemon_env="$(gnome-keyring-daemon --start --components=secrets,ssh 2>/dev/null || true)"
[[ -n "$daemon_env" ]] || exit 0

while IFS= read -r line; do
  case "$line" in
    *=*)
      export "$line"
      ;;
  esac
done <<< "$daemon_env"

if command -v dbus-update-activation-environment >/dev/null 2>&1; then
  dbus-update-activation-environment --systemd \
    GNOME_KEYRING_CONTROL GNOME_KEYRING_PID SSH_AUTH_SOCK >/dev/null 2>&1 || true
fi

if command -v systemctl >/dev/null 2>&1; then
  systemctl --user import-environment \
    GNOME_KEYRING_CONTROL GNOME_KEYRING_PID SSH_AUTH_SOCK >/dev/null 2>&1 || true
fi
