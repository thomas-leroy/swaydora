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

extract_kitty_title() {
  local cmd="${1:-}"
  sed -nE 's/.*kitty[[:space:]]+--title[[:space:]]+"([^"]+)".*/\1/p' <<<"$cmd" | head -n 1
}

window_exists_by_title() {
  local title="${1:-}"
  [[ -n "$title" ]] || return 1
  command -v swaymsg >/dev/null 2>&1 || return 1
  if command -v jq >/dev/null 2>&1; then
    swaymsg -t get_tree 2>/dev/null | jq -e --arg t "$title" '.. | objects | select(.name? == $t)' >/dev/null 2>&1
    return $?
  fi
  swaymsg -t get_tree 2>/dev/null | grep -Fq "\"name\":\"$title\""
}

focus_window_by_title() {
  local title="${1:-}"
  [[ -n "$title" ]] || return 1
  command -v swaymsg >/dev/null 2>&1 || return 1
  swaymsg "[title=\"^${title}$\"] focus" >/dev/null 2>&1 || true
}

pango_escape() {
  local s="${1:-}"
  s="${s//&/&amp;}"
  s="${s//</&lt;}"
  s="${s//>/&gt;}"
  printf '%s' "$s"
}

pretty_key_name() {
  case "${1:-}" in
    Meta|Super)
      printf ''
      ;;
    Ctrl)
      printf 'Ctrl'
      ;;
    Alt)
      printf 'Alt'
      ;;
    Shift)
      printf 'Shift'
      ;;
    Print)
      printf 'PrtSc'
      ;;
    XF86AudioRaiseVolume)
      printf 'Vol+'
      ;;
    XF86AudioLowerVolume)
      printf 'Vol-'
      ;;
    XF86AudioMute)
      printf 'Mute'
      ;;
    XF86MonBrightnessUp|XF86KbdBrightnessUp)
      printf 'Bri+'
      ;;
    XF86MonBrightnessDown|XF86KbdBrightnessDown)
      printf 'Bri-'
      ;;
    *)
      printf '%s' "$1"
      ;;
  esac
}

render_keycap_markup() {
  local key label
  key="$(trim "${1:-}")"
  label="$(pretty_key_name "$key")"
  label="$(pango_escape "$label")"
  printf "<span foreground='#ECDA9C' weight='700'>⟦</span><span background='#242835' foreground='#F8EDDC' weight='700'> %s </span><span foreground='#ECDA9C' weight='700'>⟧</span>" "$label"
}

render_shortcut_plain() {
  local shortcut parts out i
  shortcut="$(trim "${1:-}")"
  IFS='+' read -r -a parts <<<"$shortcut"
  if [[ "${#parts[@]}" -eq 0 ]]; then
    printf '%s' "$shortcut"
    return 0
  fi

  out=''
  for ((i=0; i<${#parts[@]}; i++)); do
    local key
    key="$(trim "${parts[$i]}")"
    key="$(pretty_key_name "$key")"
    if [[ $i -gt 0 ]]; then
      out+=" + "
    fi
    out+="$key"
  done
  printf '%s' "$out"
}

render_shortcut_markup() {
  local shortcut parts out i
  shortcut="$(trim "${1:-}")"

  # Keep pointer-only labels as plain text.
  if [[ "$shortcut" == Waybar* || "$shortcut" == Setup* ]]; then
    printf '%s' "$(pango_escape "$shortcut")"
    return 0
  fi

  IFS='+' read -r -a parts <<<"$shortcut"
  if [[ "${#parts[@]}" -eq 0 ]]; then
    printf '%s' "$(pango_escape "$shortcut")"
    return 0
  fi

  out=''
  for ((i=0; i<${#parts[@]}; i++)); do
    local key
    key="$(trim "${parts[$i]}")"
    if [[ $i -gt 0 ]]; then
      out+=" <span foreground='#A7A9A1' weight='700'>+</span> "
    fi
    out+="$(render_keycap_markup "$key")"
  done
  printf '%s' "$out"
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

  local line shortcut description command item item_plain choice
  local -a meta_items=() other_items=() items=()
  declare -A action_by_item
  declare -A action_by_plain

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(trim "$line")"
    [[ -z "$line" || "${line:0:1}" == "#" ]] && continue

    IFS='|' read -r shortcut description command <<<"$line"
    shortcut="$(trim "${shortcut:-}")"
    description="$(trim "${description:-}")"
    command="$(trim "${command:-}")"
    [[ -z "$shortcut" || -z "$description" ]] && continue

    item_plain="$(printf '%-34s %s' "$(render_shortcut_plain "$shortcut")" "$description")"
    item="$(printf "%s  <span foreground='#A7A9A1'>%s</span>" "$(render_shortcut_markup "$shortcut")" "$(pango_escape "$description")")"

    while [[ -v "action_by_item[$item]" ]]; do
      item+=" "
    done
    while [[ -v "action_by_plain[$item_plain]" ]]; do
      item_plain+=" "
    done

    if [[ "$shortcut" == Meta* ]]; then
      meta_items+=("$item")
    else
      other_items+=("$item")
    fi
    action_by_item["$item"]="$command"
    action_by_plain["$item_plain"]="$command"
  done <"$PALETTE_FILE"

  items=("${meta_items[@]}" "${other_items[@]}")

  [[ "${#items[@]}" -gt 0 ]] || {
    log_err "palette is empty"
    exit 1
  }

  choice="$(
    printf '%s\n' "${items[@]}" | "$menu_launcher" \
      --prompt 'Commands' \
      --allow-markup \
      --width '72%' \
      --height '62%' \
      --sort-order default
  )"
  [[ -n "${choice:-}" ]] || exit 0

  command="${action_by_item[$choice]:-}"
  if [[ -z "$command" ]]; then
    command="${action_by_plain[$choice]:-}"
  fi
  if [[ -z "$command" ]]; then
    notify-send "Command Palette" "Shortcut is documentation-only"
    exit 0
  fi

  local title
  title="$(extract_kitty_title "$command")"
  if [[ -n "${title:-}" ]] && window_exists_by_title "$title"; then
    focus_window_by_title "$title"
    exit 0
  fi

  # Run selected action detached from the menu process.
  nohup sh -lc "$command" >/dev/null 2>&1 &
}

main "$@"
