#!/usr/bin/env bash
set -euo pipefail

# Fuzzy command palette for Sway/Waybar actions.
# Source of truth: ~/.config/sway/commands_palette.list

PALETTE_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/sway/commands_palette.list"

log_err() {
  notify-send "Command Palette" "$1"
}

trim() {
  local s="${1:-}"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

main() {
  local menu_launcher="${XDG_CONFIG_HOME:-$HOME/.config}/scripts/menu_launcher.sh"
  [[ -x "$menu_launcher" ]] || {
    log_err "menu launcher is required"
    exit 1
  }

  [[ -f "$PALETTE_FILE" ]] || {
    log_err "palette file not found: $PALETTE_FILE"
    exit 1
  }

  local line shortcut description command item choice
  local -a items=()
  declare -A action_by_item

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(trim "$line")"
    [[ -z "$line" || "${line:0:1}" == "#" ]] && continue

    IFS='|' read -r shortcut description command <<<"$line"
    shortcut="$(trim "${shortcut:-}")"
    description="$(trim "${description:-}")"
    command="$(trim "${command:-}")"
    [[ -z "$shortcut" || -z "$description" ]] && continue

    item="$(printf '%-34s %s' "$shortcut" "$description")"
    while [[ -v "action_by_item[$item]" ]]; do
      item+=" "
    done

    items+=("$item")
    action_by_item["$item"]="$command"
  done <"$PALETTE_FILE"

  [[ "${#items[@]}" -gt 0 ]] || {
    log_err "palette is empty"
    exit 1
  }

  choice="$(printf '%s\n' "${items[@]}" | "$menu_launcher" --prompt 'Commands')"
  [[ -n "${choice:-}" ]] || exit 0

  command="${action_by_item[$choice]:-}"
  if [[ -z "$command" ]]; then
    notify-send "Command Palette" "Shortcut is documentation-only"
    exit 0
  fi

  # Run selected action detached from the menu process.
  nohup sh -lc "$command" >/dev/null 2>&1 &
}

main "$@"
