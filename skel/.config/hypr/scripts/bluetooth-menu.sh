#!/bin/bash

source "$HOME/.config/hypr/scripts/confirm.sh"
source "$HOME/.config/hypr/scripts/notify-progress.sh"

# md-bluetooth, reused from system-menu.sh's "Bluetooth" entry
TITLE="󰂯  sobarch: bluetooth"

# notify_on_fail runs a bluetoothctl action and, only if it fails,
# surfaces its own output as a critical notification: same
# error-passthrough convention network-menu.sh uses for nmcli, adapted
# since bluetoothctl reports failures ("Failed to connect: ...") on
# stdout rather than stderr, with a non-zero exit status alongside.
notify_on_fail() {
    local out
    out=$("$@" 2>&1) || notify-send -u critical "$TITLE" "$out"
}

# Loops back to this same picker after every action instead of exiting,
# so e.g. scanning then checking paired devices doesn't need the
# keybind re-invoked each time. Only an empty selection (Escape) breaks
# out.
while choice=$(printf "%s\n" \
    "󰐥  Toggle Power" \
    "󰂱  Scan & Connect" \
    "󰾰  Paired Devices" \
    "󰂲  Disconnect" \
    | fuzzel --dmenu --prompt "bluetooth: " --lines=4 --line-height=32)
    [ -n "$choice" ]
do
    case "$choice" in
        "󰐥  Toggle Power")
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
            id=$(notify_progress normal "$TITLE" "Scanning for Bluetooth devices..." 0 persist)
            bluetoothctl --timeout 8 scan on >/dev/null 2>&1
            notify_progress normal "$TITLE" "Scan complete." "$id" >/dev/null
            mac=$(bluetoothctl devices | sed -E 's/^Device ([0-9A-F:]+) (.*)$/\2\t\1/' | sort -f | fuzzel --dmenu --with-nth=1 --prompt "connect: " | cut -f2)
            [ -n "$mac" ] || continue
            notify_on_fail bluetoothctl pair "$mac"
            notify_on_fail bluetoothctl trust "$mac"
            notify_on_fail bluetoothctl connect "$mac"
            ;;
        "󰾰  Paired Devices")
            mac=$(bluetoothctl devices Paired | sed -E 's/^Device ([0-9A-F:]+) (.*)$/\2\t\1/' | sort -f | fuzzel --dmenu --with-nth=1 --prompt "paired: " | cut -f2)
            [ -n "$mac" ] || continue
            action=$(printf "%s\n" "󰌷  Connect" "󰌸  Disconnect" "󰆴  Remove" | fuzzel --dmenu --prompt "action: ")
            case "$action" in
                "󰌷  Connect") notify_on_fail bluetoothctl connect "$mac" ;;
                "󰌸  Disconnect") notify_on_fail bluetoothctl disconnect "$mac" ;;
                "󰆴  Remove") confirm "Remove $mac?" && notify_on_fail bluetoothctl remove "$mac" ;;
            esac
            ;;
        "󰂲  Disconnect")
            mac=$(bluetoothctl devices Connected | sed -E 's/^Device ([0-9A-F:]+) (.*)$/\2\t\1/' | sort -f | fuzzel --dmenu --with-nth=1 --prompt "disconnect: " | cut -f2)
            [ -n "$mac" ] && notify_on_fail bluetoothctl disconnect "$mac"
            ;;
    esac
done
