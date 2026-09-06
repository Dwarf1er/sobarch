#!/bin/bash
# Bound to bare Super in place of a raw `fuzzel` call (hyprland.lua's
# `menu` variable). Fuzzel's own native app-launcher mode has no way to
# show a curated set of entries at the top level and fold everything
# else behind one of them (`hide-before-typing` in fuzzel.ini is a
# global on/off, not per-entry), so that folding has to happen here
# instead: this is a plain `--dmenu` picker, and "Apps" is just a
# second, separate `fuzzel` invocation, one level in.
#
# Power is inlined here rather than shelling out to wlogout: wlogout
# has no CLI mode of its own (`--help` only lists layout/styling
# flags), and its actual layout file just ran these same five plain
# commands. Reusing them directly needs no separate themed GUI tool
# and no package to vendor for it at all.

choice=$(printf "%s\n" \
    "󰘮  System" \
    "󰢻  Sobarch" \
    "󰐦  Power" \
    "󰀻  Apps" \
    | fuzzel --dmenu --prompt "sobarch: ")

case "$choice" in
    "󰘮  System") exec bash "$HOME/.config/hypr/scripts/system-menu.sh" ;;
    "󰢻  Sobarch") exec bash "$HOME/.config/hypr/scripts/setup-menu.sh" ;;
    "󰀻  Apps") exec fuzzel ;;
    "󰐦  Power")
        power_choice=$(printf "%s\n" \
            "󰌾  Lock" \
            "󰍃  Logout" \
            "󰒲  Suspend" \
            "󰜉  Reboot" \
            "󰤂  Shutdown" \
            | fuzzel --dmenu --prompt "power: ")

        case "$power_choice" in
            "󰌾  Lock") exec hyprlock ;;
            "󰍃  Logout") exec hyprctl dispatch exit ;;
            "󰒲  Suspend") exec systemctl suspend ;;
            "󰜉  Reboot") exec systemctl reboot ;;
            "󰤂  Shutdown") exec systemctl poweroff ;;
        esac
        ;;
esac
