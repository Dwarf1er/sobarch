#!/usr/bin/env bash
# Re-downloads the current Arch ISO onto the rescue partition. Confirmed
# first since it's a gigabyte-plus download.

source "$HOME/.config/hypr/scripts/menu-lib.sh"

MENU_TITLE="sobarch: refresh rescue iso"
MENU_ICON="device-usb.svg"

confirm "Download the current Arch ISO onto the rescue partition? It's over a gigabyte, and takes a while." Download || exit 0

menu_progress "Fetching a current Arch ISO; this can take a while..." "Rescue ISO refreshed." \
    sobarch rescue-refresh ||
    menu_notify "The rescue media may be in a mixed state; refreshing again should fix it." critical
menu_done
