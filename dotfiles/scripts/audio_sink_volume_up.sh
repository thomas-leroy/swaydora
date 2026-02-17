#!/usr/bin/env bash
set -euo pipefail

# Increase default sink volume by 5% (capped to 150%).
wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+
