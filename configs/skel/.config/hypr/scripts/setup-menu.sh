#!/bin/bash

choice=$(printf "%s\n" \
    "󰑐  Update Config" \
    "󰢪  Review Conflicts" \
    "󰏔  Install" \
    "󰉦  Themes" \
    "󰑐  Refresh Rescue ISO" \
    | fuzzel --dmenu --prompt "sobarch: ")

case "$choice" in
    "󰑐  Update Config") exec bash "$HOME/.config/hypr/scripts/update-config-menu.sh" ;;
    "󰢪  Review Conflicts") exec bash "$HOME/.config/hypr/scripts/update-config-menu.sh" --review ;;
    "󰏔  Install") exec bash "$HOME/.config/hypr/scripts/setup-package-menu.sh" ;;
    "󰉦  Themes") exec bash "$HOME/.config/hypr/scripts/themes-menu.sh" ;;
    "󰑐  Refresh Rescue ISO") exec bash "$HOME/.config/hypr/scripts/refresh-rescue-menu.sh" ;;
esac
