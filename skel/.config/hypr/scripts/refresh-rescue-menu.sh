#!/usr/bin/env bash
# Exposes refresh-rescue-iso.sh (installed at
# /usr/local/lib/sobarch/refresh-rescue-iso.sh by sobarch-scripts) as a
# user-invoked action: re-fetch a current Arch ISO and re-extract its
# kernel/initramfs onto the rescue partitions rescue-iso-setup.sh laid
# out at install time. A stale rescue ISO still boots and still works;
# this is the manual refresh path Phase 2 deferred here rather than
# making automatic.
#
# Confirmed first: it's a download of over a gigabyte that rewrites the
# rescue partition, too much to start on one stray Enter. The one
# privileged step goes through `sobarch rescue-refresh` (pkexec on the
# desktop, the same PolicyKit path every other privileged action on this
# desktop already uses). Closes every open menu level once it starts,
# since there is nothing left to do in them while it runs.

source "$HOME/.config/hypr/scripts/menu-lib.sh"

MENU_TITLE="sobarch: refresh rescue iso"
MENU_ICON="device-usb.svg"

confirm "Download the current Arch ISO onto the rescue partition? It's over a gigabyte, and takes a while." Download || exit 0

menu_progress "Fetching a current Arch ISO; this can take a while..." "Rescue ISO refreshed." \
    sobarch rescue-refresh ||
    menu_notify "The rescue media may be in a mixed state; refreshing again should fix it." critical
menu_done
