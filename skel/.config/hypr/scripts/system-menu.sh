#!/bin/bash

ICONS="$HOME/.config/sobarch/icons"

choice=$(printf '%s\0icon\x1f%s\n' \
    "Audio" "$ICONS/volume-2.svg" \
    "Network" "$ICONS/wifi.svg" \
    "Bluetooth" "$ICONS/bluetooth.svg" \
    "Firmware" "$ICONS/cpu.svg" \
    | fuzzel --dmenu --prompt "system: " --lines=4 --line-height=32 --minimal-lines)

case "$choice" in
    "Audio") exec bash "$HOME/.config/hypr/scripts/audio-menu.sh" ;;
    "Network") exec bash "$HOME/.config/hypr/scripts/network-menu.sh" ;;
    "Bluetooth") exec bash "$HOME/.config/hypr/scripts/bluetooth-menu.sh" ;;
    "Firmware") exec bash "$HOME/.config/hypr/scripts/fwupd-menu.sh" ;;
esac
