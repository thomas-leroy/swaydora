#!/usr/bin/env bash
set -euo pipefail

# Ensure user systemd and DBus activation know about the live Sway/Wayland env.
if command -v dbus-update-activation-environment >/dev/null 2>&1; then
  dbus-update-activation-environment --systemd \
    DISPLAY WAYLAND_DISPLAY SWAYSOCK XDG_CURRENT_DESKTOP XDG_SESSION_TYPE \
    PATH GTK_USE_PORTAL QT_QPA_PLATFORM MOZ_ENABLE_WAYLAND >/dev/null 2>&1 || true
fi

if command -v systemctl >/dev/null 2>&1; then
  systemctl --user import-environment \
    DISPLAY WAYLAND_DISPLAY SWAYSOCK XDG_CURRENT_DESKTOP XDG_SESSION_TYPE \
    PATH GTK_USE_PORTAL QT_QPA_PLATFORM MOZ_ENABLE_WAYLAND >/dev/null 2>&1 || true

  for unit in xdg-desktop-portal.service xdg-desktop-portal-gtk.service xdg-desktop-portal-wlr.service; do
    systemctl --user restart "$unit" >/dev/null 2>&1 || true
  done
fi
