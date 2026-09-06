#!/bin/bash

choice=$(printf "%s\n" \
    "󰑐  Update Config" \
    "󰢪  Review Conflicts" \
    "󰏔  Install" \
    | fuzzel --dmenu --prompt "sobarch: ")

case "$choice" in
    "󰑐  Update Config") exec bash "$HOME/.config/hypr/scripts/update-config-menu.sh" ;;
    "󰢪  Review Conflicts") exec bash "$HOME/.config/hypr/scripts/update-config-menu.sh" --review ;;
    "󰏔  Install")
        install_choice=$(printf "%s\n" \
            "󰏔  Profile" \
            "󰏖  Package" \
            | fuzzel --dmenu --prompt "install: ")

        case "$install_choice" in
            "󰏔  Profile") exec bash "$HOME/.config/hypr/scripts/setup-profile-menu.sh" ;;
            "󰏖  Package") exec bash "$HOME/.config/hypr/scripts/setup-package-menu.sh" ;;
        esac
        ;;
esac
