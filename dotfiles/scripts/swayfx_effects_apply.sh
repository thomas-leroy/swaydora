#!/usr/bin/env bash
set -euo pipefail

# Apply SwayFX visual effects with version-tolerant command variants.
# This script never hard-fails to avoid breaking session startup.

apply_if_supported() {
  local cmd="$1"
  swaymsg "$cmd" >/dev/null 2>&1 || true
}

# Retry briefly in case compositor is still initializing.
for _ in 1 2 3 4 5; do
  # Background blur for windows.
  apply_if_supported 'blur on'
  apply_if_supported 'blur enable'
  apply_if_supported 'blur_passes 3'
  apply_if_supported 'blur_radius 10'
  # Ensure transparent client surfaces (like Kitty) still show blurred background.
  apply_if_supported 'blur_xray off'
  apply_if_supported 'blur_xray disable'
  apply_if_supported 'blur_xray false'

  # Apply opacity broadly to existing windows (Wayland and Xwayland).
  apply_if_supported '[app_id=".*"] opacity 0.9'
  apply_if_supported '[class=".*"] opacity 0.9'
  # Keep Kitty a bit more transparent so blur is perceptible.
  apply_if_supported '[app_id="kitty"] opacity 0.85'

  sleep 0.2
done

exit 0
