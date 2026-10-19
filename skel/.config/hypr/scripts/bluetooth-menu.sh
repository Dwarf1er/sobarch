#!/bin/bash
# Bluetooth panel: power, paired devices, and scan/pair. Enter toggles a
# device's connection, Alt+1 removes it.

source "$HOME/.config/hypr/scripts/menu-lib.sh"

MENU_TITLE="sobarch: bluetooth"
MENU_ICON="bluetooth.svg"

powered() { bluetoothctl show | grep -q "Powered: yes"; }

# "MAC<tab>NAME" per device, sorted by name; any args are passed through
# as a `bluetoothctl devices` filter (Paired, Connected, ...).
devices() {
    bluetoothctl devices "$@" | sed -nE 's/^Device ([0-9A-F:]+) (.*)$/\1\t\2/p' | sort -f -t $'\t' -k2
}

info_field() { sed -nE "s/^\s*$1: //p" <<<"$2"; }

# Paired devices, using each device's own icon name with a generic fallback.
# Appends connected devices' names to $connected.
add_device_rows() {
    local mac name info state battery
    while IFS=$'\t' read -r mac name; do
        info=$(bluetoothctl info "$mac")
        state=""
        if grep -q "Connected: yes" <<<"$info"; then
            battery=$(info_field "Battery Percentage" "$info" | sed -nE 's/.*\(([0-9]+)\)/\1/p')
            state="connected${battery:+ · $battery%}"
            connected+=("$name")
        fi
        menu_add "$mac" "$name" "$(info_field Icon "$info"),devices.svg" "$state"
    done < <(devices Paired)
}

device_action() {
    local mac="$1" info name
    info=$(bluetoothctl info "$mac")
    name=$(info_field Name "$info")
    case "$MENU_KEY" in
        0)
            if grep -q "Connected: yes" <<<"$info"; then
                menu_run bluetoothctl disconnect "$mac"
            else
                menu_progress "Connecting to $name..." "Connected to $name." bluetoothctl connect "$mac"
            fi
            ;;
        1) confirm "Remove $name? It will need pairing again to reconnect." Remove && menu_run bluetoothctl remove "$mac" ;;
    esac
}

scan() { bluetoothctl --timeout 8 scan on >/dev/null 2>&1 || true; }

# Prints only the failing step's output, so a failure toast isn't
# prefixed by every earlier step's success chatter.
pair_device() {
    local step out
    bluetoothctl agent NoInputNoOutput >/dev/null
    bluetoothctl default-agent >/dev/null
    for step in pair trust connect; do
        out=$(bluetoothctl "$step" "$1" 2>&1) || { printf '%s\n' "$out"; return 1; }
    done
}

# fuzzel can't update an open list, so scan first, then list results.
# Devices that need a passkey can't pair here; use bluetoothctl.
scan_and_pair() {
    local mac name paired
    menu_progress "Scanning for devices..." "Scan complete." scan
    paired=$(devices Paired | cut -f1)
    menu_reset
    while IFS=$'\t' read -r mac name; do
        grep -qxF "$mac" <<<"$paired" && continue
        menu_add "$mac" "$name" "$(info_field Icon "$(bluetoothctl info "$mac")"),devices.svg"
    done < <(devices)
    if ((${#MENU_IDS[@]} == 0)); then
        menu_notify "No new devices found."
        return
    fi
    menu_show pair "↵ pair and connect" || return
    name=$(info_field Name "$(bluetoothctl info "$MENU_ID")")
    menu_progress "Pairing with $name..." "Connected to $name." pair_device "$MENU_ID"
}

selected=""
while :; do
    menu_reset
    connected=()
    if powered; then
        menu_add power "Turn Off" power.svg
        menu_add scan "Scan for Devices" bluetooth-connected.svg
        add_device_rows
        mesg="Bluetooth on · ${#connected[@]} connected"
        ((${#MENU_IDS[@]} > 2)) && mesg+=$'\n'"↵ connect/disconnect · Alt+1 remove"
    else
        menu_add power "Turn On" power.svg
        mesg="Bluetooth off"
    fi

    menu_show bluetooth "$mesg" "$selected" || break
    selected="$MENU_ID"
    case "$MENU_ID" in
        power)
            if powered; then
                menu_run bluetoothctl power off
            else
                menu_run bluetoothctl power on
            fi
            ;;
        scan) scan_and_pair ;;
        *) device_action "$MENU_ID" ;;
    esac
done
