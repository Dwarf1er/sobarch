#!/bin/bash

# md-bluetooth (U+F00AF), reused from system-menu.sh's "Bluetooth" entry
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
    "󰂱  Scan & Connect" \
    "󰾰  Paired Devices" \
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
    "󰂱  Scan & Connect")
        bluetoothctl power on
        bluetoothctl agent NoInputNoOutput
        bluetoothctl default-agent
        bluetoothctl --timeout 8 scan on >/dev/null 2>&1
        mac=$(bluetoothctl devices | sed -E 's/^Device ([0-9A-F:]+) (.*)$/\2\t\1/' | sort -f | fuzzel --dmenu --with-nth=1 --prompt "connect: " | cut -f2)
        [ -n "$mac" ] || exit 0
        notify_on_fail bluetoothctl pair "$mac"
        notify_on_fail bluetoothctl trust "$mac"
        notify_on_fail bluetoothctl connect "$mac"
        ;;
    "󰾰  Paired Devices")
        mac=$(bluetoothctl devices Paired | sed -E 's/^Device ([0-9A-F:]+) (.*)$/\2\t\1/' | sort -f | fuzzel --dmenu --with-nth=1 --prompt "paired: " | cut -f2)
        [ -n "$mac" ] || exit 0
        action=$(printf "%s\n" "󰌷  Connect" "󰌸  Disconnect" "󰆴  Remove" | fuzzel --dmenu --prompt "action: ")
        case "$action" in
            "󰌷  Connect") notify_on_fail bluetoothctl connect "$mac" ;;
            "󰌸  Disconnect") notify_on_fail bluetoothctl disconnect "$mac" ;;
            "󰆴  Remove") notify_on_fail bluetoothctl remove "$mac" ;;
        esac
        ;;
    "󰂲  Disconnect")
        mac=$(bluetoothctl devices Connected | sed -E 's/^Device ([0-9A-F:]+) (.*)$/\2\t\1/' | sort -f | fuzzel --dmenu --with-nth=1 --prompt "disconnect: " | cut -f2)
        [ -n "$mac" ] && notify_on_fail bluetoothctl disconnect "$mac"
        ;;
esac
