#!/bin/bash

# md-web (U+F059F). Held in a variable rather than pasted as a literal
# glyph (unlike this menu's other entries) since it sits in Unicode's
# private-use area and can't be typed/reviewed reliably as a plain
# character in a diff.
ICON_DOCS=$'\U000F059F'

choice=$(printf "%s\n" \
    "󰑐  Update Config" \
    "󰢪  Review Conflicts" \
    "󰏔  Install" \
    "󰉦  Themes" \
    "󰸉  Wallpaper" \
    "󰑐  Refresh Rescue ISO" \
    "${ICON_DOCS}  Docs" \
    | fuzzel --dmenu --prompt "sobarch: ")

case "$choice" in
    "󰑐  Update Config") exec bash "$HOME/.config/hypr/scripts/update-config-menu.sh" ;;
    "󰢪  Review Conflicts") exec bash "$HOME/.config/hypr/scripts/update-config-menu.sh" --review ;;
    "󰏔  Install") exec bash "$HOME/.config/hypr/scripts/setup-package-menu.sh" ;;
    "󰉦  Themes") exec bash "$HOME/.config/hypr/scripts/themes-menu.sh" ;;
    "󰸉  Wallpaper") exec bash "$HOME/.config/hypr/scripts/wallpaper-menu.sh" ;;
    "󰑐  Refresh Rescue ISO") exec bash "$HOME/.config/hypr/scripts/refresh-rescue-menu.sh" ;;
    "${ICON_DOCS}  Docs") exec xdg-open "https://sobarch.antoinepoulin.com" ;;
esac
