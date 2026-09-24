#!/bin/bash

source "$HOME/.config/hypr/scripts/notify-progress.sh"

# md-chip (U+F061A): same icon system-menu.sh's own "Firmware" entry uses.
TITLE=$'\U000F061A'"  sobarch: firmware"

# notify_on_fail runs an fwupdmgr action and, only if it fails, surfaces
# its own output as a critical notification: fwupdmgr reports failures
# on stdout/stderr combined, with a non-zero exit status alongside (same
# convention bluetooth-menu.sh uses for bluetoothctl).
notify_on_fail() {
    local out
    out=$("$@" 2>&1) || notify-send -u critical "$TITLE" "$out"
}

# md-update (U+F06B0), md-package_down (U+F03D4, same icon
# setup-package-menu.sh's own install action uses), md-expansion_card
# (U+F08AE). Held in variables rather than pasted as literal glyphs
# (unlike this directory's other menu scripts) since these codepoints
# sit in Unicode's private-use area and can't be typed/reviewed
# reliably as plain characters in a diff.
ICON_UPDATE=$'\U000F06B0'
ICON_INSTALL=$'\U000F03D4'
ICON_DEVICES=$'\U000F08AE'

choice=$(printf "%s\n" \
    "${ICON_UPDATE}  Check for Updates" \
    "${ICON_INSTALL}  Install Updates" \
    "${ICON_DEVICES}  List Devices" \
    | fuzzel --dmenu --prompt "firmware: ")

case "$choice" in
    "${ICON_UPDATE}  Check for Updates")
        id=$(notify_progress normal "$TITLE" "Refreshing firmware metadata..." 0 persist)
        if out=$(fwupdmgr refresh 2>&1); then
            notify_progress normal "$TITLE" "Firmware metadata refreshed." "$id" >/dev/null
        else
            notify_progress critical "$TITLE" "$out" "$id" >/dev/null
        fi
        fwupdmgr get-updates 2>&1 | fuzzel --dmenu --hide-prompt --prompt ""
        ;;
    "${ICON_INSTALL}  Install Updates")
        id=$(notify_progress normal "$TITLE" "Installing firmware updates..." 0 persist)
        if out=$(fwupdmgr update -y 2>&1); then
            notify_progress normal "$TITLE" "Firmware updates installed." "$id" >/dev/null
        else
            notify_progress critical "$TITLE" "$out" "$id" >/dev/null
        fi
        ;;
    "${ICON_DEVICES}  List Devices")
        fwupdmgr get-devices 2>&1 | fuzzel --dmenu --hide-prompt --prompt ""
        ;;
esac
