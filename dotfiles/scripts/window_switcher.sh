#!/usr/bin/env bash
set -euo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/window_switcher"
ACTIVE_FILE="$CACHE_DIR/active"
direction='next'
action='cycle'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cycle-next)
      action='cycle'
      direction='next'
      shift
      ;;
    --cycle-prev|--reverse)
      action='cycle'
      direction='prev'
      shift
      ;;
    --accept)
      action='accept'
      shift
      ;;
    --cancel)
      action='cancel'
      shift
      ;;
    *)
      printf '[window_switcher] unsupported arg: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

log_err() {
  notify-send "Window Switcher" "$1"
}

trim() {
  local s="${1:-}"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

switcher_is_active() {
  [[ -f "$ACTIVE_FILE" ]] && pgrep -x wofi >/dev/null 2>&1
}

send_key() {
  local key="${1:-}"
  command -v wtype >/dev/null 2>&1 || return 1
  wtype -k "$key"
}

focus_selected_window() {
  local selected="$1"
  shift
  local record con_id workspace app title item

  for record in "$@"; do
    IFS=$'\t' read -r con_id workspace app title <<<"$record"
    workspace="$(trim "$workspace")"
    app="$(trim "$app")"
    title="$(trim "$title")"
    item="$(printf '%-12s %-20s %s' "[$workspace]" "$app" "$title")"
    if [[ "$item" == "$selected" ]]; then
      swaymsg "[con_id=$con_id]" focus >/dev/null 2>&1 || {
        log_err "unable to focus selected window"
        return 1
      }
      return 0
    fi
  done

  return 1
}

build_records() {
  local tree
  tree="$(swaymsg -t get_tree 2>/dev/null || true)"
  [[ -n "$tree" ]] || return 1

  jq -r '
    def walk_tree:
      ., ((.nodes[]?, .floating_nodes[]?) | walk_tree);

    [
      walk_tree
      | select(.type == "workspace" and .name != "__i3_scratch") as $ws
      | ($ws.nodes[]?, $ws.floating_nodes[]?) | walk_tree
      | select((.type == "con" or .type == "floating_con") and .pid != null and ((.name // "") | length) > 0)
      | {
          id: .id,
          workspace: $ws.name,
          app: (.app_id // .window_properties.class // "Application"),
          title: .name,
          focused: (.focused // false)
        }
    ]
    | unique_by(.id)
    | sort_by((if .focused then 0 else 1 end), .workspace, .app, .title)
    | .[]
    | [.id, .workspace, .app, .title]
    | @tsv
  ' <<<"$tree"
}

start_switcher() {
  command -v swaymsg >/dev/null 2>&1 || {
    log_err "swaymsg is required"
    exit 1
  }
  command -v jq >/dev/null 2>&1 || {
    log_err "jq is required"
    exit 1
  }
  command -v wofi >/dev/null 2>&1 || {
    log_err "wofi is required"
    exit 1
  }
  command -v wtype >/dev/null 2>&1 || {
    log_err "wtype is required for Alt+Tab cycling"
    exit 1
  }

  mkdir -p "$CACHE_DIR"

  local -a records items
  local record con_id workspace app title item selected

  mapfile -t records < <(build_records)
  [[ "${#records[@]}" -gt 0 ]] || {
    log_err "no open windows found"
    exit 1
  }

  items=()
  for record in "${records[@]}"; do
    IFS=$'\t' read -r con_id workspace app title <<<"$record"
    workspace="$(trim "$workspace")"
    app="$(trim "$app")"
    title="$(trim "$title")"
    items+=("$(printf '%-12s %-20s %s' "[$workspace]" "$app" "$title")")
  done

  : >"$ACTIVE_FILE"
  trap 'rm -f "$ACTIVE_FILE"' EXIT

  (
    sleep 0.12
    if [[ "$direction" == 'prev' ]]; then
      send_key Up >/dev/null 2>&1 || true
    else
      send_key Down >/dev/null 2>&1 || true
    fi
  ) &

  selected="$(
    printf '%s\n' "${items[@]}" | wofi \
      --dmenu \
      --prompt 'Windows' \
      --matching fuzzy \
      --insensitive \
      --width '72%' \
      --height '55%' \
      --sort-order default
  )"
  [[ -n "${selected:-}" ]] || exit 0

  focus_selected_window "$selected" "${records[@]}" || log_err "unable to resolve selected window"
}

cycle_switcher() {
  if switcher_is_active; then
    if [[ "$direction" == 'prev' ]]; then
      send_key Up >/dev/null 2>&1 || log_err "unable to move selection upward"
    else
      send_key Down >/dev/null 2>&1 || log_err "unable to move selection downward"
    fi
    exit 0
  fi

  start_switcher
}

accept_switcher() {
  switcher_is_active || exit 0
  send_key Return >/dev/null 2>&1 || log_err "unable to accept selected window"
}

cancel_switcher() {
  switcher_is_active || exit 0
  send_key Escape >/dev/null 2>&1 || log_err "unable to cancel window switcher"
}

case "$action" in
  cycle)
    cycle_switcher
    ;;
  accept)
    accept_switcher
    ;;
  cancel)
    cancel_switcher
    ;;
esac
