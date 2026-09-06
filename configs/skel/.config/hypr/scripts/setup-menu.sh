#!/bin/bash

choice=$(printf "%s\n" \
    "󰑐  Update Config" \
    "󰢪  Review Conflicts" \
    "󰏔  Install Profile" \
    | fuzzel --dmenu --prompt "setup: ")

case "$choice" in
    "󰑐  Update Config") exec bash "$HOME/.config/hypr/scripts/update-config-menu.sh" ;;
    "󰢪  Review Conflicts") exec bash "$HOME/.config/hypr/scripts/update-config-menu.sh" --review ;;
    "󰏔  Install Profile") exec bash "$HOME/.config/hypr/scripts/setup-profile-menu.sh" ;;
esac
