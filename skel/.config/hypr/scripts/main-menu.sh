#!/bin/bash
# Bound to bare Super in place of a raw `fuzzel` call (hyprland.lua's
# `menu` variable). Fuzzel's own native app-launcher mode has no way to
# show a curated set of entries at the top level and fold everything
# else behind one of them (`hide-before-typing` in fuzzel.ini is a
# global on/off, not per-entry), so that folding has to happen here
# instead: this is a plain `--dmenu` picker, and "Apps" is just a
# second, separate `fuzzel` invocation, one level in. Escape in the app
# launcher comes back here; launching something closes everything.
#
# Power is inlined here rather than shelling out to wlogout: wlogout
# has no CLI mode of its own (`--help` only lists layout/styling
# flags), and its actual layout file just ran these same five plain
# commands. Reusing them directly needs no separate themed GUI tool
# and no package to vendor for it at all.

source "$HOME/.config/hypr/scripts/menu-lib.sh"

MENU_TITLE="sobarch: power"
MENU_ICON="power.svg"

# Every action here ends the session or leaves the desktop, so each one
# closes the whole menu stack once it returns (hyprlock, for instance,
# returns only after unlocking).
power_menu() {
    local selected=""
    while menu_show power "" "$selected"; do
        selected="$MENU_ID"
        case "$MENU_ID" in
            lock) menu_run hyprlock && menu_done ;;
            logout) confirm "Log out now? Unsaved work in open apps will be lost." "Log Out" &&
                menu_run hyprctl dispatch exit && menu_done ;;
            suspend) confirm "Suspend now?" "Suspend" && menu_run systemctl suspend && menu_done ;;
            reboot) confirm "Restart now?" "Restart" && menu_run systemctl reboot && menu_done ;;
            shutdown) confirm "Shut down now?" "Shut Down" && menu_run systemctl poweroff && menu_done ;;
        esac
    done
}

selected=""
while :; do
    menu_reset
    menu_add apps "Apps" apps.svg
    menu_add system "System" settings.svg
    menu_add sobarch "Sobarch" siot.svg
    menu_add keybinds "Keybinds" keyboard.svg
    menu_add power "Power" power.svg
    menu_show sobarch "" "$selected" || break
    selected="$MENU_ID"
    case "$MENU_ID" in
        apps) fuzzel && menu_done ;;
        system) menu_sub system-menu.sh ;;
        sobarch) menu_sub setup-menu.sh ;;
        keybinds) menu_sub keybinds-menu.sh ;;
        power)
            menu_reset
            menu_add lock "Lock" lock.svg
            menu_add logout "Log Out" logout.svg
            menu_add suspend "Suspend" moon.svg
            menu_add reboot "Restart" refresh.svg
            menu_add shutdown "Shut Down" power.svg
            power_menu
            ;;
    esac
done
