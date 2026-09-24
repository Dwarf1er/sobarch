#!/bin/bash

source "$HOME/.config/hypr/scripts/notify-progress.sh"

# md-chip: same icon system-menu.sh's own "Firmware" entry uses.
TITLE="󰘚  sobarch: firmware"

# notify_on_fail runs an fwupdmgr action and, only if it fails, surfaces
# its own output as a critical notification: fwupdmgr reports failures
# on stdout/stderr combined, with a non-zero exit status alongside (same
# convention bluetooth-menu.sh uses for bluetoothctl).
notify_on_fail() {
    local out
    out=$("$@" 2>&1) || notify-send -u critical "$TITLE" "$out"
}

choice=$(printf "%s\n" \
    "󰚰  Check for Updates" \
    "󰏔  Install Updates" \
    "󰢮  List Devices" \
    | fuzzel --dmenu --prompt "firmware: " --lines=3 --line-height=40)

case "$choice" in
    "󰚰  Check for Updates")
        id=$(notify_progress normal "$TITLE" "Refreshing firmware metadata..." 0 persist)
        if out=$(fwupdmgr refresh 2>&1); then
            notify_progress normal "$TITLE" "Firmware metadata refreshed." "$id" >/dev/null
        else
            notify_progress critical "$TITLE" "$out" "$id" >/dev/null
        fi
        fwupdmgr get-updates 2>&1 | fuzzel --dmenu --hide-prompt --prompt ""
        ;;
    "󰏔  Install Updates")
        id=$(notify_progress normal "$TITLE" "Installing firmware updates..." 0 persist)
        if out=$(fwupdmgr update -y 2>&1); then
            notify_progress normal "$TITLE" "Firmware updates installed." "$id" >/dev/null
        else
            notify_progress critical "$TITLE" "$out" "$id" >/dev/null
        fi
        ;;
    "󰢮  List Devices")
        fwupdmgr get-devices 2>&1 | fuzzel --dmenu --hide-prompt --prompt ""
        ;;
esac
