#!/usr/bin/env bash
set -euo pipefail

# Report battery state for Waybar and degrade gracefully on AC-powered systems
# without any battery, such as some desktops or docked machines.

find_first_matching_supply() {
  local base_path="$1"
  local prefix="$2"
  local entry path

  for entry in "$base_path"/"$prefix"*; do
    if [[ -e "$entry" ]]; then
      path="$entry"
      printf '%s\n' "$path"
      return 0
    fi
  done

  return 1
}

read_supply_value() {
  local file_path="$1"

  if [[ -r "$file_path" ]]; then
    tr -d '\n' <"$file_path"
    return 0
  fi

  return 1
}

power_supply_root='/sys/class/power_supply'

if [[ ! -d "$power_supply_root" ]]; then
  printf '{"text":"󰂑 ?","class":"warn","tooltip":"Power supply information unavailable"}\n'
  exit 0
fi

battery_path=''
if battery_path="$(find_first_matching_supply "$power_supply_root" 'BAT' 2>/dev/null || true)"; then
  :
fi

adapter_path=''
for adapter_prefix in AC ADP ACAD AC0 ADP0 ACPI0003:00; do
  adapter_path="$(find_first_matching_supply "$power_supply_root" "$adapter_prefix" 2>/dev/null || true)"
  if [[ -n "$adapter_path" ]]; then
    break
  fi
done

adapter_online='unknown'
if [[ -n "$adapter_path" ]]; then
  adapter_online="$(read_supply_value "$adapter_path/online" || printf 'unknown')"
fi

if [[ -z "$battery_path" ]]; then
  if [[ "$adapter_online" == '1' ]]; then
    printf '{"text":" AC","class":["no-battery","plugged"],"tooltip":"AC power connected (no battery detected)"}\n'
  else
    printf '{"text":"󰂑 ?","class":"warn","tooltip":"No battery detected"}\n'
  fi
  exit 0
fi

capacity="$(read_supply_value "$battery_path/capacity" || printf '')"
status_raw="$(read_supply_value "$battery_path/status" || printf 'Unknown')"
status="$(printf '%s' "$status_raw" | tr '[:upper:]' '[:lower:]')"

if [[ ! "$capacity" =~ ^[0-9]+$ ]]; then
  printf '{"text":"󰂑 ?","class":"warn","tooltip":"Battery capacity unavailable"}\n'
  exit 0
fi

icon='󰁹'
state_class='high'

if (( capacity <= 15 )); then
  icon='󰂃'
  state_class='critical'
elif (( capacity <= 30 )); then
  icon='󰁺'
  state_class='low'
elif (( capacity <= 60 )); then
  icon='󰁽'
  state_class='medium'
elif (( capacity <= 85 )); then
  icon='󰂀'
  state_class='high'
else
  icon='󰁹'
  state_class='full'
fi

status_class="$status"
tooltip_status="$status_raw"

case "$status" in
  charging)
    icon='󰂄'
    if (( capacity >= 90 )); then
      icon='󰂅'
    fi
    ;;
  full)
    icon='󰂅'
    state_class='full'
    ;;
  not\ charging)
    status_class='plugged'
    tooltip_status='Plugged in'
    ;;
  discharging|unknown)
    ;;
  *)
    status_class='unknown'
    ;;
esac

printf '{"text":"%s %s%%","class":["%s","%s"],"tooltip":"Battery: %s%% (%s)"}\n' \
  "$icon" "$capacity" "$status_class" "$state_class" "$capacity" "$tooltip_status"
