#!/bin/bash
# Main menu, bound to a tap of Super. fuzzel's app launcher can't fold
# entries behind a submenu, so "Apps" opens it one level in.

source "$HOME/.config/hypr/scripts/menu-lib.sh"

MENU_TITLE="sobarch: power"
MENU_ICON="power.svg"

# Each action leaves the desktop, so close the whole menu stack after it.
power_menu() {
    local selected=""
    while menu_show power "" "$selected"; do
        selected="$MENU_ID"
        case "$MENU_ID" in
            lock) menu_run hyprlock && menu_done ;;
            logout) confirm "Log out now? Unsaved work in open apps will be lost." "Log Out" &&
                menu_run hyprctl dispatch 'hl.dsp.exit()' && menu_done ;;
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
