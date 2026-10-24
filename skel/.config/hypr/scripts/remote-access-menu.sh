#!/bin/bash
# Start or stop the Sunshine streaming host, or open its web UI.

source "$HOME/.config/hypr/scripts/menu-lib.sh"

MENU_TITLE="sobarch: remote access"
MENU_ICON="plug.svg"

UNIT="app-dev.lizardbyte.app.Sunshine.service"

running() { systemctl --user is-active --quiet "$UNIT"; }

selected=""
while :; do
    menu_reset
    if running; then
        menu_add toggle "Stop Sunshine" x.svg
        mesg="Sunshine running"
    else
        menu_add toggle "Start Sunshine" plug.svg
        mesg="Sunshine stopped"
    fi
    menu_add webui "Open Web UI" world.svg "first run: create the admin account"

    menu_show remote "$mesg" "$selected" || break
    selected="$MENU_ID"
    case "$MENU_ID" in
        toggle)
            if running; then
                menu_run systemctl --user stop "$UNIT"
            else
                menu_run systemctl --user start "$UNIT"
            fi
            ;;
        webui) xdg-open "https://localhost:47990" & menu_done ;;
    esac
done
