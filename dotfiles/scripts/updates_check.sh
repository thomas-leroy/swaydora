#!/usr/bin/env bash
set -euo pipefail

# Cache location and behavior for updates count.
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles"
CACHE_FILE="$CACHE_DIR/updates_count"
TTL="${UPDATES_CACHE_TTL:-900}"
PLAIN="${1:-}"

# Ensure cache directory exists.
mkdir -p "$CACHE_DIR"

# Return success when cached value is still fresh.
fresh_cache() {
  [[ -f "$CACHE_FILE" ]] || return 1
  local now mtime
  now="$(date +%s)"
  mtime="$(stat -c %Y "$CACHE_FILE")"
  (( now - mtime < TTL ))
}

# Query dnf for available updates and return package count.
count_updates() {
  local output rc

  # dnf uses exit code 100 when updates are available.
  set +e
  output="$(dnf -q check-update 2>/dev/null)"
  rc=$?
  set -e

  # For unexpected dnf failures, return 0 to keep Waybar stable.
  if [[ $rc -ne 0 && $rc -ne 100 ]]; then
    echo 0
    return 0
  fi

  # Count package-like lines in output.
  awk '/^[[:alnum:]_.+-]+[[:space:]]+[[:alnum:]_.:+~-]+[[:space:]]/{count++} END{print count+0}' <<<"$output"
}

# Use cached value when possible, otherwise recompute and refresh cache.
if fresh_cache; then
  count="$(cat "$CACHE_FILE")"
else
  count="$(count_updates)"
  printf '%s\n' "$count" > "$CACHE_FILE"
fi

# Plain mode is used by notification scripts.
if [[ "$PLAIN" == '--plain' ]]; then
  printf '%s\n' "$count"
  exit 0
fi

# Emit Waybar JSON payload.
if [[ "$count" -gt 0 ]]; then
  printf '{"text":" %s","class":"warn","tooltip":"%s updates available"}\n' "$count" "$count"
else
  printf '{"text":" 0","tooltip":"System up to date"}\n'
fi
