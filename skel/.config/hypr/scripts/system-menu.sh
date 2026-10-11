#!/bin/bash

ICONS="$HOME/.config/sobarch/icons"

# Power Profile only exists on laptops: tlp-pd (and so tlpctl) is
# installed only when the installer detects a laptop chassis.
entries=(
    "Audio" "$ICONS/volume-2.svg"
    "Network" "$ICONS/wifi.svg"
    "Bluetooth" "$ICONS/bluetooth.svg"
)
command -v tlpctl >/dev/null && entries+=("Power Profile" "$ICONS/battery-2.svg")
entries+=("Firmware" "$ICONS/cpu.svg")

choice=$(printf '%s\0icon\x1f%s\n' "${entries[@]}" \
    | fuzzel --dmenu --prompt "system: " --lines=$((${#entries[@]} / 2)) --line-height=32 --minimal-lines)

case "$choice" in
    "Audio") exec bash "$HOME/.config/hypr/scripts/audio-menu.sh" ;;
    "Network") exec bash "$HOME/.config/hypr/scripts/network-menu.sh" ;;
    "Bluetooth") exec bash "$HOME/.config/hypr/scripts/bluetooth-menu.sh" ;;
    "Power Profile") exec bash "$HOME/.config/hypr/scripts/power-profile-menu.sh" ;;
    "Firmware") exec bash "$HOME/.config/hypr/scripts/fwupd-menu.sh" ;;
esac
