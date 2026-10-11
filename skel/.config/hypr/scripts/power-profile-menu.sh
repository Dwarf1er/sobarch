#!/bin/bash

ICONS="$HOME/.config/sobarch/icons"

# battery-2: same icon system-menu.sh's own "Power Profile" entry uses.
TITLE="sobarch: power profile"

# tlpctl talks to tlp-pd, which exposes the same profile names
# power-profiles-daemon does (performance, balanced, power-saver).
current=$(tlpctl get 2>/dev/null)

# The active profile gets a trailing marker; it is stripped again below
# before the choice reaches tlpctl.
label() {
    if [ "$current" = "$2" ]; then
        printf '%s  (active)' "$1"
    else
        printf '%s' "$1"
    fi
}

choice=$(printf '%s\0icon\x1f%s\n' \
    "$(label Performance performance)" "$ICONS/cpu.svg" \
    "$(label Balanced balanced)" "$ICONS/battery-2.svg" \
    "$(label 'Power Saver' power-saver)" "$ICONS/battery-1.svg" \
    | fuzzel --dmenu --prompt "profile: " --lines=3 --line-height=40 --minimal-lines)

case "${choice%  (active)}" in
    "Performance") profile=performance ;;
    "Balanced") profile=balanced ;;
    "Power Saver") profile=power-saver ;;
    *) exit 0 ;;
esac

if err=$(tlpctl set "$profile" 2>&1); then
    notify-send -i "$ICONS/battery-2.svg" "$TITLE" "Switched to $profile."
else
    notify-send -u critical -i "$ICONS/battery-2.svg" "$TITLE" "$err"
fi
