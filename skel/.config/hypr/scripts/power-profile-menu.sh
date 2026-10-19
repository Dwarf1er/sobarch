#!/bin/bash
# Power profiles via tlpctl (tlp-pd). Stays open so the "active" marker moves.

source "$HOME/.config/hypr/scripts/menu-lib.sh"

MENU_TITLE="sobarch: power profile"
MENU_ICON="battery-2.svg"

selected=""
while :; do
    current=$(tlpctl get 2>/dev/null)
    [ -n "$selected" ] || selected="$current"
    menu_reset
    menu_add performance "Performance" cpu.svg "$([ "$current" = performance ] && echo active)"
    menu_add balanced "Balanced" battery-2.svg "$([ "$current" = balanced ] && echo active)"
    menu_add power-saver "Power Saver" battery-1.svg "$([ "$current" = power-saver ] && echo active)"
    menu_show "power profile" "" "$selected" || break
    selected="$MENU_ID"
    menu_run tlpctl set "$MENU_ID"
done
