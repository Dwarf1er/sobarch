#!/bin/bash

# md-bluetooth: system-menu.sh's own "Bluetooth" entry is missing its
# icon glyph (confirmed: that line has two plain spaces, not a
# character, where every sibling entry has one), so this is the first
# use of it in the repo rather than a reuse.
TITLE=$'\U000F00AF'"  sobarch: bluetooth"

# notify_on_fail runs a bluetoothctl action and, only if it fails,
# surfaces its own output as a critical notification: same
# error-passthrough convention network-menu.sh uses for nmcli, adapted
# since bluetoothctl reports failures ("Failed to connect: ...") on
# stdout rather than stderr, with a non-zero exit status alongside.
notify_on_fail() {
    local out
    out=$("$@" 2>&1) || notify-send -u critical "$TITLE" "$out"
}

choice=$(printf "%s\n" \
    "⏻  Toggle Power" \
    "  Scan & Connect" \
    "  Paired Devices" \
    "󰂲  Disconnect" \
    | fuzzel --dmenu --prompt "bluetooth: ")

case "$choice" in
    "⏻  Toggle Power")
        if bluetoothctl show | grep -q "Powered: yes"; then
            notify_on_fail bluetoothctl power off
        else
            notify_on_fail bluetoothctl power on
        fi
        ;;
    "  Scan & Connect")
        bluetoothctl power on
        bluetoothctl agent NoInputNoOutput
        bluetoothctl default-agent
        bluetoothctl --timeout 8 scan on >/dev/null 2>&1
        mac=$(bluetoothctl devices | cut -d' ' -f2- | fuzzel --dmenu --prompt "connect: " | awk '{print $1}')
        [ -n "$mac" ] || exit 0
        notify_on_fail bluetoothctl pair "$mac"
        notify_on_fail bluetoothctl trust "$mac"
        notify_on_fail bluetoothctl connect "$mac"
        ;;
    "  Paired Devices")
        mac=$(bluetoothctl devices Paired | cut -d' ' -f2- | fuzzel --dmenu --prompt "paired: " | awk '{print $1}')
        [ -n "$mac" ] || exit 0
        action=$(printf "%s\n" "󰌷  Connect" "󰌸  Disconnect" "󰆴  Remove" | fuzzel --dmenu --prompt "action: ")
        case "$action" in
            "󰌷  Connect") notify_on_fail bluetoothctl connect "$mac" ;;
            "󰌸  Disconnect") notify_on_fail bluetoothctl disconnect "$mac" ;;
            "󰆴  Remove") notify_on_fail bluetoothctl remove "$mac" ;;
        esac
        ;;
    "󰂲  Disconnect")
        mac=$(bluetoothctl devices Connected | cut -d' ' -f2- | fuzzel --dmenu --prompt "disconnect: " | awk '{print $1}')
        [ -n "$mac" ] && notify_on_fail bluetoothctl disconnect "$mac"
        ;;
esac
