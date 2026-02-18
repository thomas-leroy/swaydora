#!/usr/bin/env bash
set -euo pipefail

# Validate required tools.
command -v wpctl >/dev/null 2>&1 || { notify-send "Audio" "wpctl not found"; exit 1; }
MENU_LAUNCHER="${XDG_CONFIG_HOME:-$HOME/.config}/scripts/menu_launcher.sh"
[[ -x "$MENU_LAUNCHER" ]] || { notify-send "Audio" "menu launcher not found"; exit 1; }

# Parse sink lines from wpctl status output.
mapfile -t lines < <(wpctl status | awk '
  /Sinks:/ {in_sinks=1; next}
  /Sources:/ {in_sinks=0}
  in_sinks && /\./ {print}
')

# Exit quietly when no sink is available.
if [[ ${#lines[@]} -eq 0 ]]; then
  notify-send "Audio" "No sinks found"
  exit 0
fi

# Build menu labels and keep sink id mapping.
menu_items=()
declare -A id_by_label

for line in "${lines[@]}"; do
  id="$(sed -nE 's/.* ([0-9]+)\..*/\1/p' <<<"$line")"
  name="$(sed -E 's/^.*[0-9]+\.\s*//; s/\s*\[vol:.*$//' <<<"$line" | sed 's/^\*\s*//')"
  [[ -n "$id" && -n "$name" ]] || continue
  label="$id: $name"
  menu_items+=("$label")
  id_by_label["$label"]="$id"
done

# Ask user to pick a sink through launcher.
choice="$(printf '%s\n' "${menu_items[@]}" | "$MENU_LAUNCHER" --prompt 'Sink')"
[[ -n "$choice" ]] || exit 0

# Resolve selected sink id.
sink_id="${id_by_label[$choice]:-}"
[[ -n "$sink_id" ]] || exit 0

# Apply new default sink and notify.
wpctl set-default "$sink_id"
notify-send "Audio" "Default sink set to: ${choice#*: }"
