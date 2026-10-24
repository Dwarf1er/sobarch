#!/bin/bash
# Start or stop the Sunshine streaming host, choose whether it gets its own
# 1080p virtual monitor while it runs, or open its web UI.

source "$HOME/.config/hypr/scripts/menu-lib.sh"

MENU_TITLE="sobarch: remote access"
MENU_ICON="plug.svg"

UNIT="app-dev.lizardbyte.app.Sunshine.service"
VIRTUAL="sunshine-virtual"
CONF="$HOME/.config/sunshine/sunshine.conf"
# Present when Sunshine should stream a virtual monitor of its own.
FLAG="$HOME/.config/sobarch/remote-virtual-monitor"

running() { systemctl --user is-active --quiet "$UNIT"; }

virtual_present() { hyprctl monitors all | grep -q "^Monitor $VIRTUAL "; }

# Sunshine reads output_name once at startup; a name that doesn't exist
# makes it fall back to a physical monitor, so only keep it while the
# virtual output does.
sync_output_name() {
    mkdir -p "${CONF%/*}"
    touch "$CONF"
    sed -i '/^output_name[[:space:]]*=/d' "$CONF"
    if virtual_present; then
        echo "output_name = $VIRTUAL" >>"$CONF"
    fi
}

# reset-failed so quick repeated toggles don't trip systemd's start limit.
restart_if_running() {
    ! running || {
        systemctl --user reset-failed "$UNIT" 2>/dev/null
        systemctl --user restart "$UNIT"
    }
}

# Parked far right of the real monitors so the cursor can't reach it.
create_virtual() {
    hyprctl output create headless "$VIRTUAL" &&
        hyprctl eval "hl.monitor({ output = \"$VIRTUAL\", mode = \"1920x1080@60\", position = \"10000x0\", scale = 1 })"
}

remove_virtual() { hyprctl output remove "$VIRTUAL"; }

# Makes the virtual output match the setting; the output only exists
# while Sunshine runs.
apply_virtual() {
    if [ -e "$FLAG" ] && running; then
        virtual_present || create_virtual
    else
        ! virtual_present || remove_virtual
    fi
    sync_output_name
}

toggle_virtual() {
    if [ -e "$FLAG" ]; then
        rm -f "$FLAG"
    else
        mkdir -p "${FLAG%/*}"
        touch "$FLAG"
    fi
    menu_run apply_virtual
    menu_run restart_if_running
}

start_sunshine() {
    if [ -e "$FLAG" ]; then
        virtual_present || create_virtual || return
    fi
    sync_output_name
    systemctl --user reset-failed "$UNIT" 2>/dev/null
    systemctl --user start "$UNIT"
}

stop_sunshine() {
    systemctl --user stop "$UNIT"
    apply_virtual
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
    if [ -e "$FLAG" ]; then
        menu_add virtual "Virtual Monitor" devices.svg "on · own 1920x1080 screen"
    else
        menu_add virtual "Virtual Monitor" devices.svg "off · stream a real monitor"
    fi
    menu_add webui "Open Web UI" world.svg "first run: create the admin account"

    menu_show remote "$mesg" "$selected" || break
    selected="$MENU_ID"
    case "$MENU_ID" in
        toggle)
            if running; then
                menu_run stop_sunshine
            else
                menu_run start_sunshine
            fi
            ;;
        virtual) toggle_virtual ;;
        webui) xdg-open "https://localhost:47990" & menu_done ;;
    esac
done
