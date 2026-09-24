#!/bin/bash

choice=$(printf "%s\n" \
    "󰕾  Audio" \
    "󰤨  Network" \
    "󰂯  Bluetooth" \
    "󰘚  Firmware" \
    | fuzzel --dmenu --prompt "system: " --lines=4 --line-height=32)

case "$choice" in
    "󰕾  Audio") exec bash "$HOME/.config/hypr/scripts/audio-menu.sh" ;;
    "󰤨  Network") exec bash "$HOME/.config/hypr/scripts/network-menu.sh" ;;
    "󰂯  Bluetooth") exec bash "$HOME/.config/hypr/scripts/bluetooth-menu.sh" ;;
    "󰘚  Firmware") exec bash "$HOME/.config/hypr/scripts/fwupd-menu.sh" ;;
esac
