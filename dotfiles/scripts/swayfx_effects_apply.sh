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
  apply_if_supported 'blur enable'
  apply_if_supported 'blur_passes 2'
  apply_if_supported 'blur_radius 6'

  # Light opacity for windows (90%).
  apply_if_supported 'default_opacity 0.9'
  apply_if_supported 'default_opacity 0.9 0.9'
  apply_if_supported 'opacity 0.9'

  sleep 0.2
done

exit 0
