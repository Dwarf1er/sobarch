#!/bin/bash

ICONS="$HOME/.config/sobarch/icons"

# "Refresh Rescue ISO" only exists if rescue media was provisioned at
# install (rescue-iso-setup.sh labels that partition RESCUE).
rescue_entry=()
lsblk -rno LABEL 2>/dev/null | grep -qx RESCUE && rescue_entry=("Refresh Rescue ISO" "$ICONS/device-usb.svg")

choice=$(printf '%s\0icon\x1f%s\n' \
    "Update System" "$ICONS/refresh.svg" \
    "Review Conflicts" "$ICONS/git-merge.svg" \
    "Install" "$ICONS/download.svg" \
    "Themes" "$ICONS/palette.svg" \
    "Wallpaper" "$ICONS/photo.svg" \
    "Default Apps" "$ICONS/apps.svg" \
    "${rescue_entry[@]}" \
    "Docs" "$ICONS/book.svg" \
    | fuzzel --dmenu --prompt "sobarch: " --minimal-lines)

case "$choice" in
    "Update System") exec bash "$HOME/.config/hypr/scripts/update-system-menu.sh" ;;
    "Review Conflicts") exec bash "$HOME/.config/hypr/scripts/update-system-menu.sh" --review ;;
    "Install") exec bash "$HOME/.config/hypr/scripts/setup-package-menu.sh" ;;
    "Themes") exec bash "$HOME/.config/hypr/scripts/themes-menu.sh" ;;
    "Wallpaper") exec bash "$HOME/.config/hypr/scripts/wallpaper-menu.sh" ;;
    "Default Apps") exec bash "$HOME/.config/hypr/scripts/mimetype-menu.sh" ;;
    "Refresh Rescue ISO") exec bash "$HOME/.config/hypr/scripts/refresh-rescue-menu.sh" ;;
    "Docs") exec xdg-open "https://sobarch.antoinepoulin.com" ;;
esac
