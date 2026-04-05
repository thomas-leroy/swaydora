#!/usr/bin/env bash
set -euo pipefail

# Cache location and behavior for updates count.
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles"
CACHE_FILE="$CACHE_DIR/updates_count"
LOCK_FILE="$CACHE_DIR/updates_count.lock"
TTL="${UPDATES_CACHE_TTL:-900}"
DNF_TIMEOUT_SEC="${DNF_TIMEOUT_SEC:-20}"
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
  output="$(timeout --foreground "$DNF_TIMEOUT_SEC" dnf -q check-update 2>/dev/null)"
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

read_cached_count() {
  if [[ -f "$CACHE_FILE" ]]; then
    cat "$CACHE_FILE"
  else
    echo 0
  fi
}

# Use cached value when possible, otherwise recompute and refresh cache.
if fresh_cache; then
  count="$(read_cached_count)"
else
  if command -v flock >/dev/null 2>&1; then
    exec 9>"$LOCK_FILE"
    if flock -n 9; then
      count="$(count_updates)"
      printf '%s\n' "$count" > "$CACHE_FILE"
    else
      count="$(read_cached_count)"
    fi
  else
    count="$(count_updates)"
    printf '%s\n' "$count" > "$CACHE_FILE"
  fi
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
