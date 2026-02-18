#!/usr/bin/env bash
set -euo pipefail

# Fuzzy launcher for machine-management TUI tools.
# Source of truth: ~/.config/sway/tools_menu.list

MENU_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/sway/tools_menu.list"

log_err() {
  notify-send "Tools Menu" "$1"
}

trim() {
  local s="${1:-}"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

main() {
  command -v fuzzel >/dev/null 2>&1 || {
    log_err "fuzzel is required"
    exit 1
  }

  [[ -f "$MENU_FILE" ]] || {
    log_err "menu file not found: $MENU_FILE"
    exit 1
  }

  local line name description command item choice
  local -a items=()
  declare -A action_by_item

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(trim "$line")"
    [[ -z "$line" || "${line:0:1}" == "#" ]] && continue

    IFS='|' read -r name description command <<<"$line"
    name="$(trim "${name:-}")"
    description="$(trim "${description:-}")"
    command="$(trim "${command:-}")"
    [[ -z "$name" || -z "$description" || -z "$command" ]] && continue

    item="$(printf '%-18s %s' "$name" "$description")"
    while [[ -v "action_by_item[$item]" ]]; do
      item+=" "
    done

    items+=("$item")
    action_by_item["$item"]="$command"
  done <"$MENU_FILE"

  [[ "${#items[@]}" -gt 0 ]] || {
    log_err "menu is empty"
    exit 1
  }

  choice="$(printf '%s\n' "${items[@]}" | fuzzel --dmenu --prompt 'Tools')"
  [[ -n "${choice:-}" ]] || exit 0

  command="${action_by_item[$choice]:-}"
  [[ -n "$command" ]] || exit 0

  # Run selected tool detached from the launcher process.
  nohup sh -lc "$command" >/dev/null 2>&1 &
}

main "$@"
