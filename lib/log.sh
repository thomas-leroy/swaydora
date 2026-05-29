#!/usr/bin/env bash
set -euo pipefail

log_info() {
  printf '[INFO] %s\n' "$*"
}

log_ok() {
  printf '[OK] %s\n' "$*"
}

log_warn() {
  printf '[WARN] %s\n' "$*"
}

log_plan() {
  printf '[PLAN] %s\n' "$*"
}

log_error() {
  printf '[ERROR] %s\n' "$*" >&2
}
