#!/usr/bin/env bash
set -euo pipefail

# Toggle mute state of the default microphone source.
wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
