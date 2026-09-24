#!/bin/bash

# "Refresh Rescue ISO" uses md-usb_flash_drive rather than md-refresh
# (which "Update Config" already carries): both used to render the
# same circular-arrow glyph despite being unrelated actions,
# indistinguishable at a glance in this same list.
choice=$(printf "%s\n" \
    "󰑐  Update Config" \
    "󰢪  Review Conflicts" \
    "󰏔  Install" \
    "󰉦  Themes" \
    "󰸉  Wallpaper" \
    "󰢻  Default Apps" \
    "󱊞  Refresh Rescue ISO" \
    "󰖟  Docs" \
    | fuzzel --dmenu --prompt "sobarch: ")

case "$choice" in
    "󰑐  Update Config") exec bash "$HOME/.config/hypr/scripts/update-config-menu.sh" ;;
    "󰢪  Review Conflicts") exec bash "$HOME/.config/hypr/scripts/update-config-menu.sh" --review ;;
    "󰏔  Install") exec bash "$HOME/.config/hypr/scripts/setup-package-menu.sh" ;;
    "󰉦  Themes") exec bash "$HOME/.config/hypr/scripts/themes-menu.sh" ;;
    "󰸉  Wallpaper") exec bash "$HOME/.config/hypr/scripts/wallpaper-menu.sh" ;;
    "󰢻  Default Apps") exec bash "$HOME/.config/hypr/scripts/mimetype-menu.sh" ;;
    "󱊞  Refresh Rescue ISO") exec bash "$HOME/.config/hypr/scripts/refresh-rescue-menu.sh" ;;
    "󰖟  Docs") exec xdg-open "https://sobarch.antoinepoulin.com" ;;
esac
