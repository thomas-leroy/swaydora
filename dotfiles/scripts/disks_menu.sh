#!/usr/bin/env bash
set -euo pipefail

# Validate required tools.
command -v fuzzel >/dev/null 2>&1 || { notify-send "Disks" "fuzzel not found"; exit 1; }
command -v lsblk >/dev/null 2>&1 || { notify-send "Disks" "lsblk not found"; exit 1; }
command -v udisksctl >/dev/null 2>&1 || { notify-send "Disks" "udisksctl not found"; exit 1; }

# Collect removable partitions with mount metadata.
mapfile -t devices < <(lsblk -rno NAME,TYPE,RM,HOTPLUG,MOUNTPOINT,LABEL,MODEL | awk '
  $2 == "part" && ($3 == "1" || $4 == "1") {
    name=$1
    mount=$5
    label=$6
    model=$7
    if (label == "") label="(no-label)"
    if (mount == "") mount="(not-mounted)"
    print name "|" mount "|" label "|" model
  }
')

# Exit quietly when no removable partition is found.
if [[ ${#devices[@]} -eq 0 ]]; then
  notify-send "Disks" "No removable partitions found"
  exit 0
fi

# Build action menu and keep action/device mapping.
menu=()
declare -A by_label

for item in "${devices[@]}"; do
  IFS='|' read -r name mount label model <<<"$item"
  dev="/dev/$name"
  if [[ "$mount" == '(not-mounted)' ]]; then
    action='mount'
  else
    action='unmount'
  fi
  display="$action $dev [$label] $mount $model"
  menu+=("$display")
  by_label["$display"]="$action|$dev"
done

# Ask user which disk action to run.
choice="$(printf '%s\n' "${menu[@]}" | fuzzel --dmenu --prompt 'Disks')"
[[ -n "$choice" ]] || exit 0

# Run mount/unmount action and notify result.
IFS='|' read -r action dev <<<"${by_label[$choice]}"
if [[ "$action" == 'mount' ]]; then
  if udisksctl mount -b "$dev"; then
    notify-send "Disks" "Mounted $dev"
  else
    notify-send "Disks" "Failed to mount $dev"
  fi
else
  if udisksctl unmount -b "$dev"; then
    notify-send "Disks" "Unmounted $dev"
  else
    notify-send "Disks" "Failed to unmount $dev"
  fi
fi
