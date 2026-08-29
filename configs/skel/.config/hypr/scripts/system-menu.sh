#!/bin/bash
# Top-level fuzzel menu that routes to audio/network/bluetooth submenus.

choice=$(printf "%s\n" \
    "󰕾  Audio" \
    "󰤨  Network" \
    "  Bluetooth" \
    | fuzzel --dmenu --prompt "system: ")

case "$choice" in
    "󰕾  Audio") exec bash "$HOME/.config/hypr/scripts/audio-menu.sh" ;;
    "󰤨  Network") exec bash "$HOME/.config/hypr/scripts/network-menu.sh" ;;
    "  Bluetooth") exec bash "$HOME/.config/hypr/scripts/bluetooth-menu.sh" ;;
esac
