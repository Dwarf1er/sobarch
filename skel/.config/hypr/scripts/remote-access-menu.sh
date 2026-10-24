#!/bin/bash
# Start or stop the Sunshine streaming host, add or remove its dedicated
# 1080p virtual monitor, or open its web UI.

source "$HOME/.config/hypr/scripts/menu-lib.sh"

MENU_TITLE="sobarch: remote access"
MENU_ICON="plug.svg"

UNIT="app-dev.lizardbyte.app.Sunshine.service"
VIRTUAL="sunshine-virtual"
CONF="$HOME/.config/sunshine/sunshine.conf"

running() { systemctl --user is-active --quiet "$UNIT"; }

virtual_present() { hyprctl monitors all | grep -q "^Monitor $VIRTUAL "; }

# Sunshine reads output_name once at startup; a name that doesn't exist
# makes it fall back to a physical monitor, so only keep it while the
# virtual output does.
sync_output_name() {
    mkdir -p "${CONF%/*}"
    touch "$CONF"
    sed -i '/^output_name[[:space:]]*=/d' "$CONF"
    virtual_present && echo "output_name = $VIRTUAL" >>"$CONF"
}

restart_if_running() { ! running || systemctl --user restart "$UNIT"; }

# Parked far right of the real monitors so the cursor can't reach it.
create_virtual() {
    hyprctl output create headless "$VIRTUAL" &&
        hyprctl eval "hl.monitor({ output = \"$VIRTUAL\", mode = \"1920x1080@60\", position = \"10000x0\", scale = 1 })"
}

remove_virtual() { hyprctl output remove "$VIRTUAL"; }

toggle_virtual() {
    if virtual_present; then
        menu_run remove_virtual
    else
        menu_run create_virtual
    fi
    sync_output_name
    menu_run restart_if_running
}

start_sunshine() {
    sync_output_name
    systemctl --user start "$UNIT"
}

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
    if virtual_present; then
        menu_add virtual "Remove Virtual Monitor" x.svg "1920x1080"
        mesg+=" · virtual monitor on"
    else
        menu_add virtual "Add Virtual Monitor" devices.svg "own 1920x1080 screen for Moonlight"
        mesg+=" · virtual monitor off"
    fi
    menu_add webui "Open Web UI" world.svg "first run: create the admin account"

    menu_show remote "$mesg" "$selected" || break
    selected="$MENU_ID"
    case "$MENU_ID" in
        toggle)
            if running; then
                menu_run systemctl --user stop "$UNIT"
            else
                menu_run start_sunshine
            fi
            ;;
        virtual) toggle_virtual ;;
        webui) xdg-open "https://localhost:47990" & menu_done ;;
    esac
done
