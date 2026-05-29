#!/usr/bin/env bash
set -euo pipefail

is_git_repo() {
  local repo_dir="${1:-.}"
  git -C "$repo_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

git_branch() {
  local repo_dir="${1:-.}"

  git -C "$repo_dir" branch --show-current 2>/dev/null || true
}

git_is_dirty() {
  local repo_dir="${1:-.}"

  [[ -n "$(git -C "$repo_dir" status --porcelain 2>/dev/null)" ]]
}
