#!/bin/bash

# md-chip (U+F061A). Held in a variable rather than pasted as a literal
# glyph (unlike this menu's other entries) since it sits in Unicode's
# private-use area and can't be typed/reviewed reliably as a plain
# character in a diff.
ICON_FIRMWARE=$'\U000F061A'

choice=$(printf "%s\n" \
    "󰕾  Audio" \
    "󰤨  Network" \
    "󰂯  Bluetooth" \
    "${ICON_FIRMWARE}  Firmware" \
    | fuzzel --dmenu --prompt "system: ")

case "$choice" in
    "󰕾  Audio") exec bash "$HOME/.config/hypr/scripts/audio-menu.sh" ;;
    "󰤨  Network") exec bash "$HOME/.config/hypr/scripts/network-menu.sh" ;;
    "󰂯  Bluetooth") exec bash "$HOME/.config/hypr/scripts/bluetooth-menu.sh" ;;
    "${ICON_FIRMWARE}  Firmware") exec bash "$HOME/.config/hypr/scripts/fwupd-menu.sh" ;;
esac
