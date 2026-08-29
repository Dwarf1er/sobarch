#!/bin/bash
# Fuzzel-based bluetooth menu, replaces blueman-manager.

choice=$(printf "%s\n" \
    "⏻  Toggle Power" \
    "  Scan & Connect" \
    "  Paired Devices" \
    "󰂲  Disconnect" \
    | fuzzel --dmenu --prompt "bluetooth: ")

case "$choice" in
    "⏻  Toggle Power")
        if bluetoothctl show | grep -q "Powered: yes"; then
            bluetoothctl power off
        else
            bluetoothctl power on
        fi
        ;;
    "  Scan & Connect")
        bluetoothctl power on
        bluetoothctl agent NoInputNoOutput
        bluetoothctl default-agent
        bluetoothctl --timeout 8 scan on >/dev/null 2>&1
        mac=$(bluetoothctl devices | cut -d' ' -f2- | fuzzel --dmenu --prompt "connect: " | awk '{print $1}')
        [ -n "$mac" ] || exit 0
        bluetoothctl pair "$mac"
        bluetoothctl trust "$mac"
        bluetoothctl connect "$mac"
        ;;
    "  Paired Devices")
        mac=$(bluetoothctl devices Paired | cut -d' ' -f2- | fuzzel --dmenu --prompt "paired: " | awk '{print $1}')
        [ -n "$mac" ] || exit 0
        action=$(printf "%s\n" "󰌷  Connect" "󰌸  Disconnect" "󰆴  Remove" | fuzzel --dmenu --prompt "action: ")
        case "$action" in
            "󰌷  Connect") bluetoothctl connect "$mac" ;;
            "󰌸  Disconnect") bluetoothctl disconnect "$mac" ;;
            "󰆴  Remove") bluetoothctl remove "$mac" ;;
        esac
        ;;
    "󰂲  Disconnect")
        mac=$(bluetoothctl devices Connected | cut -d' ' -f2- | fuzzel --dmenu --prompt "disconnect: " | awk '{print $1}')
        [ -n "$mac" ] && bluetoothctl disconnect "$mac"
        ;;
esac
