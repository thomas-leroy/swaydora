#!/usr/bin/env bash
set -euo pipefail

# Close all mapped windows in the current Sway session.
if ! command -v swaymsg >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

tree="$(swaymsg -t get_tree 2>/dev/null || true)"
if [[ -z "$tree" ]]; then
  exit 0
fi

mapfile -t ids < <(
  jq -r '
    .. | objects
    | select((.type? == "con" or .type? == "floating_con") and (.pid? != null))
    | .id
  ' <<<"$tree"
)

for id in "${ids[@]}"; do
  swaymsg "[con_id=$id]" kill >/dev/null 2>&1 || true
done
