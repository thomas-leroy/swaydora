#!/usr/bin/env bash
set -euo pipefail

# Return warning state when wpctl is unavailable.
if ! command -v wpctl >/dev/null 2>&1; then
  printf '{"text":" ?","class":"warn","tooltip":"wpctl not found"}\n'
  exit 0
fi

# Read source state and report muted/active.
status="$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null || true)"
if grep -q 'MUTED' <<<"$status"; then
  printf '{"text":"","class":"warn","tooltip":"Microphone muted"}\n'
else
  printf '{"text":"","tooltip":"Microphone active"}\n'
fi
