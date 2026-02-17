#!/usr/bin/env bash
set -euo pipefail

# Decrease default source volume by 5%.
wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%-
