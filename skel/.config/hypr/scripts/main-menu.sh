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

source "$HOME/.config/hypr/scripts/confirm.sh"

ICONS="$HOME/.config/sobarch/icons"
TITLE="sobarch: power"

# --lines/--line-height match this list's real entry count (5) instead
# of fuzzel.ini's global lines=8/line-height=22, which reserved room for
# three rows nothing was ever going to fill. Window keeps its usual
# overall size; the real entries stretch to fill it instead of leaving
# dead space below "Apps". Same fix applied to the Power submenu below
# (also 5 entries). --minimal-lines added on top since every row now
# carries an icon: an empty leftover row below a short list renders a
# duplicated, mispositioned icon copy (see wallpaper-menu.sh's own
# comment on this same fuzzel bug).
choice=$(printf '%s\0icon\x1f%s\n' \
    "Apps" "$ICONS/apps.svg" \
    "System" "$ICONS/settings.svg" \
    "Sobarch" "$ICONS/package.svg" \
    "Keybinds" "$ICONS/keyboard.svg" \
    "Power" "$ICONS/power.svg" \
    | fuzzel --dmenu --prompt "sobarch: " --lines=5 --line-height=27 --minimal-lines)

case "$choice" in
    "Apps") exec fuzzel ;;
    "System") exec bash "$HOME/.config/hypr/scripts/system-menu.sh" ;;
    "Sobarch") exec bash "$HOME/.config/hypr/scripts/setup-menu.sh" ;;
    "Keybinds") exec bash "$HOME/.config/hypr/scripts/keybinds-menu.sh" ;;
    "Power")
        power_choice=$(printf '%s\0icon\x1f%s\n' \
            "Lock" "$ICONS/lock.svg" \
            "Logout" "$ICONS/logout.svg" \
            "Suspend" "$ICONS/moon.svg" \
            "Reboot" "$ICONS/refresh.svg" \
            "Shutdown" "$ICONS/power.svg" \
            | fuzzel --dmenu --prompt "power: " --lines=5 --line-height=27 --minimal-lines)

        case "$power_choice" in
            "Lock") hyprlock || notify-send -u critical -i "$ICONS/power.svg" "$TITLE" "Failed to lock screen." ;;
            "Logout") confirm "Log out now?" && { hyprctl dispatch exit || notify-send -u critical -i "$ICONS/power.svg" "$TITLE" "Failed to log out."; } ;;
            "Suspend") confirm "Suspend now?" && { systemctl suspend || notify-send -u critical -i "$ICONS/power.svg" "$TITLE" "Failed to suspend."; } ;;
            "Reboot") confirm "Reboot now?" && { systemctl reboot || notify-send -u critical -i "$ICONS/power.svg" "$TITLE" "Failed to reboot."; } ;;
            "Shutdown") confirm "Shut down now?" && { systemctl poweroff || notify-send -u critical -i "$ICONS/power.svg" "$TITLE" "Failed to shut down."; } ;;
        esac
        ;;
esac
