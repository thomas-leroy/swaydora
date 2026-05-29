#!/usr/bin/env bash
set -euo pipefail

warn() {
  printf 'portal_session_fix: %s\n' "$*" >&2
}

# Ensure user systemd and DBus activation know about the live Sway/Wayland env.
if command -v dbus-update-activation-environment >/dev/null 2>&1; then
  dbus-update-activation-environment --systemd \
    WAYLAND_DISPLAY \
    XDG_CURRENT_DESKTOP \
    XDG_SESSION_TYPE \
    XDG_SESSION_DESKTOP \
    DISPLAY \
    SWAYSOCK >/dev/null 2>&1 || warn "failed to update DBus activation environment"
fi

if command -v systemctl >/dev/null 2>&1; then
  systemctl --user import-environment \
    WAYLAND_DISPLAY \
    XDG_CURRENT_DESKTOP \
    XDG_SESSION_TYPE \
    XDG_SESSION_DESKTOP \
    DISPLAY \
    SWAYSOCK >/dev/null 2>&1 || warn "failed to import systemd user environment"

  if systemctl --user cat sway-session.target >/dev/null 2>&1; then
    systemctl --user start sway-session.target >/dev/null 2>&1 || \
      warn "failed to start sway-session.target; portal activation may fail"
  fi

  systemctl --user restart xdg-desktop-portal.service >/dev/null 2>&1 || \
    warn "failed to restart xdg-desktop-portal.service; check graphical session and portal logs"
fi
