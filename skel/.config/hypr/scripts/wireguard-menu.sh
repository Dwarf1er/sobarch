#!/bin/bash
# VPN panel. Any machine: import a WireGuard config and switch tunnels (the
# tunnels are NetworkManager connections). The machine hosting the tunnel
# also gets server setup and per-device configs, shown as a QR code.

source "$HOME/.config/hypr/scripts/menu-lib.sh"

MENU_TITLE="sobarch: vpn"
MENU_ICON="world.svg"

HELPER="/usr/local/lib/sobarch/wireguard-server.sh"
STATE_DIR="/etc/sobarch"
DEVICES="$STATE_DIR/wireguard-devices"
ENDPOINT="$STATE_DIR/wireguard-endpoint"
OUT_DIR="$HOME/.config/sobarch/wireguard"

server() { pkexec "$HELPER" "$@"; }

server_exists() { [ -f "$DEVICES" ]; }
server_on() { systemctl is-active --quiet wg-quick@wg0.service; }

# "NAME<US>yes|no" for every WireGuard connection.
tunnels() {
    nmcli -e no -t -f NAME,TYPE,ACTIVE connection show 2>/dev/null |
        awk -F: '$(NF - 1) == "wireguard" {
            name = $1; for (i = 2; i <= NF - 2; i++) name = name ":" $i
            print name "\037" $NF
        }' | sort -f
}

# Same text-mode QR as the network menu's Wi-Fi share.
show_qr() {
    local title="$1" payload="$2" text_color
    text_color=$(sed -n 's/^text=//p' "$HOME/.config/fuzzel/colors.ini" 2>/dev/null)
    fuzzel --dmenu --hide-prompt --minimal-lines --mesg-mode=expand --line-height=16 \
        ${text_color:+--message-color="$text_color"} \
        --mesg="$title"$'\n\n'"$(qrencode -t UTF8 "$payload" | sed 's/^/ /')" </dev/null
}

import_menu() {
    local f
    menu_reset
    while IFS= read -r f; do
        menu_add "$f" "${f##*/}" file.svg "${f%/*}"
    done < <(find "$HOME" "$HOME/Downloads" -maxdepth 1 -name '*.conf' -type f 2>/dev/null | sort -u)
    if ((${#MENU_IDS[@]} == 0)); then
        menu_notify "No .conf files in your home or Downloads folder."
        return
    fi
    menu_show import "Pick a WireGuard config file" || return
    f="$MENU_ID"
    local name="${f##*/}"
    name="${name%.conf}"
    menu_run nmcli connection import type wireguard file "$f" || return
    menu_run nmcli connection modify "$name" connection.autoconnect no
    menu_notify "Imported “$name”. Turn it on from this menu."
    confirm "Delete $f? NetworkManager keeps its own copy, and the file holds a private key." Delete && rm -f "$f"
}

tunnels_menu() {
    local selected="" name active
    while :; do
        menu_reset
        while IFS=$'\037' read -r name active; do
            menu_add "$name" "$name" world.svg "$([ "$active" = yes ] && echo on || echo off)"
        done < <(tunnels)
        menu_show tunnels "↵ turn on/off · Alt+1 forget" "$selected" || return
        selected="$MENU_ID"
        name="$MENU_ID"
        case "$MENU_KEY" in
            0)
                if nmcli -e no -t -f NAME connection show --active | grep -qxF "$name"; then
                    menu_run nmcli connection down id "$name"
                else
                    menu_progress "Connecting to $name..." "Connected to $name." nmcli connection up id "$name"
                fi
                ;;
            1) confirm "Forget “$name”? Its keys are deleted too." Forget &&
                menu_run nmcli connection delete id "$name" ;;
        esac
    done
}

setup_server() {
    local host
    host=$(MENU_PLACEHOLDER="Your public IP or hostname" menu_input "address" \
        "Public address devices will connect to (the port forward must point here)") || return
    menu_progress "Setting up the server..." "Server is on." server init "$host"
}

add_device() {
    local name conf err
    name=$(MENU_PLACEHOLDER="e.g. laptop (letters, digits, dashes)" menu_input "device" "Name for the new device") || return
    mkdir -p "$OUT_DIR"
    chmod 700 "$OUT_DIR"
    conf="$OUT_DIR/$name.conf"
    # umask: the config holds the device's private key.
    err=$(mktemp)
    if ! (umask 077; server add "$name" >"$conf" 2>"$err"); then
        rm -f "$conf"
        menu_notify "$(cat "$err")" critical
        rm -f "$err"
        return
    fi
    rm -f "$err"
    menu_notify "Saved $conf. It holds a private key: delete it once the device has it."
    show_qr "Scan with the WireGuard app, or copy $name.conf to a sobarch machine" "$(cat "$conf")"
}

devices_menu() {
    local selected="" name ip
    while :; do
        menu_reset
        while IFS=$'\t' read -r name ip; do
            menu_add "$name" "$name" devices.svg "$ip"
        done <"$DEVICES"
        menu_show devices "Alt+1 remove" "$selected" || return
        selected="$MENU_ID"
        if [ "$MENU_KEY" = 1 ]; then
            confirm "Remove “$MENU_ID”? That device loses access." Remove && menu_run server remove "$MENU_ID"
        fi
    done
}

change_endpoint() {
    local host
    host=$(MENU_PLACEHOLDER="Your public IP or hostname" menu_input "address" \
        "Public address (currently $(<"$ENDPOINT")). Applies to devices added from now on.") || return
    menu_run server endpoint "$host"
}

selected=""
while :; do
    menu_reset
    menu_add tunnels "Tunnels" world.svg "$(tunnels | wc -l) saved"
    menu_add import "Import Config" download.svg
    if server_exists; then
        server_on && state="on" || state="off"
        menu_add devices "Devices" devices.svg "$(wc -l <"$DEVICES") added"
        menu_add add "Add Device" plug.svg
        menu_add endpoint "Public Address" settings.svg "$(<"$ENDPOINT")"
        menu_add power "Server" power.svg "$state"
        menu_add teardown "Remove Server" trash.svg
        mesg="WireGuard server $state"
    else
        menu_add setup "Set Up Server" power.svg "host this machine's tunnel"
        mesg="No server on this machine"
    fi

    menu_show vpn "$mesg" "$selected" || break
    selected="$MENU_ID"
    case "$MENU_ID" in
        tunnels) tunnels_menu ;;
        import) import_menu ;;
        setup) setup_server ;;
        add) add_device ;;
        devices) devices_menu ;;
        endpoint) change_endpoint ;;
        power)
            if server_on; then
                menu_run server off
            else
                menu_run server on
            fi
            ;;
        teardown) confirm "Remove the server? Every device loses access." Remove && menu_run server teardown ;;
    esac
done
