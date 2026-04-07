#!/usr/bin/env bash

# Shared logging helpers for setup scripts.
LOG_PREFIX="${LOG_PREFIX:-setup}"
LOG_COLOR_INFO="${LOG_COLOR_INFO:-$'\033[34m'}"
LOG_COLOR_WARN="${LOG_COLOR_WARN:-$'\033[33m'}"
LOG_COLOR_ERROR="${LOG_COLOR_ERROR:-$'\033[31m'}"
LOG_COLOR_SUCCESS="${LOG_COLOR_SUCCESS:-$'\033[32m'}"
LOG_COLOR_RESET="${LOG_COLOR_RESET:-$'\033[0m'}"

setup_logger() {
  LOG_PREFIX="$1"
}

log_emit() {
  local level="$1"
  local color="$2"
  local stream="$3"
  shift 3

  printf '%s[%s] [%s] [%s] %s%s\n' "$color" "$(date -Iseconds)" "$LOG_PREFIX" "$level" "$*" "$LOG_COLOR_RESET" >&"$stream"
}

log_info() {
  log_emit INFO "$LOG_COLOR_INFO" 1 "$@"
}

log_warn() {
  log_emit WARN "$LOG_COLOR_WARN" 1 "$@"
}

log_error() {
  log_emit ERROR "$LOG_COLOR_ERROR" 2 "$@"
}

log_success() {
  log_emit SUCCESS "$LOG_COLOR_SUCCESS" 1 "$@"
}

# Backward-compatible default logger for existing call sites.
log() {
  log_info "$@"
}

log_command() {
  local arg

  printf '%s[%s] [%s] [INFO] DRY_RUN: would run:' "$LOG_COLOR_INFO" "$(date -Iseconds)" "$LOG_PREFIX"
  for arg in "$@"; do
    printf ' %q' "$arg"
  done
  printf '%s\n' "$LOG_COLOR_RESET"
}
