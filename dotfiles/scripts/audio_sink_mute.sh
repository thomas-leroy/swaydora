#!/usr/bin/env bash
set -euo pipefail

# Toggle mute state of the default output sink.
wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
