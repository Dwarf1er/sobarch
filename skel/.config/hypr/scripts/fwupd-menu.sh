#!/bin/bash

source "$HOME/.config/hypr/scripts/notify-progress.sh"

ICONS="$HOME/.config/sobarch/icons"

# cpu: same icon system-menu.sh's own "Firmware" entry uses.
TITLE="sobarch: firmware"

# notify_on_fail runs an fwupdmgr action and, only if it fails, surfaces
# its own output as a critical notification: fwupdmgr reports failures
# on stdout/stderr combined, with a non-zero exit status alongside (same
# convention bluetooth-menu.sh uses for bluetoothctl).
notify_on_fail() {
    local out
    out=$("$@" 2>&1) || notify-send -u critical -i "$ICONS/cpu.svg" "$TITLE" "$out"
}

choice=$(printf '%s\0icon\x1f%s\n' \
    "Check for Updates" "$ICONS/refresh.svg" \
    "Install Updates" "$ICONS/download.svg" \
    "List Devices" "$ICONS/devices.svg" \
    | fuzzel --dmenu --prompt "firmware: " --lines=3 --line-height=40 --minimal-lines)

case "$choice" in
    "Check for Updates")
        id=$(notify_progress normal "$TITLE" "Refreshing firmware metadata..." 0 persist "$ICONS/cpu.svg")
        if out=$(fwupdmgr refresh 2>&1); then
            notify_progress normal "$TITLE" "Firmware metadata refreshed." "$id" "" "$ICONS/cpu.svg" >/dev/null
        else
            notify_progress critical "$TITLE" "$out" "$id" "" "$ICONS/cpu.svg" >/dev/null
        fi
        fwupdmgr get-updates 2>&1 | fuzzel --dmenu --hide-prompt --prompt ""
        ;;
    "Install Updates")
        id=$(notify_progress normal "$TITLE" "Installing firmware updates..." 0 persist "$ICONS/cpu.svg")
        if out=$(fwupdmgr update -y 2>&1); then
            notify_progress normal "$TITLE" "Firmware updates installed." "$id" "" "$ICONS/cpu.svg" >/dev/null
        else
            notify_progress critical "$TITLE" "$out" "$id" "" "$ICONS/cpu.svg" >/dev/null
        fi
        ;;
    "List Devices")
        fwupdmgr get-devices 2>&1 | fuzzel --dmenu --hide-prompt --prompt ""
        ;;
esac
