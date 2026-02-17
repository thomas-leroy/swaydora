#!/usr/bin/env bash
set -euo pipefail

# Decrease default sink volume by 5%.
wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
