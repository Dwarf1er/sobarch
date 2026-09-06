#!/bin/bash

choice=$(printf "%s\n" \
    "󰑐  Update Config" \
    "󰢪  Review Conflicts" \
    "󰏔  Install" \
    | fuzzel --dmenu --prompt "sobarch: ")

case "$choice" in
    "󰑐  Update Config") exec bash "$HOME/.config/hypr/scripts/update-config-menu.sh" ;;
    "󰢪  Review Conflicts") exec bash "$HOME/.config/hypr/scripts/update-config-menu.sh" --review ;;
    "󰏔  Install") exec bash "$HOME/.config/hypr/scripts/setup-package-menu.sh" ;;
esac
