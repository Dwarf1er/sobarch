#!/bin/bash
# Overview of every system control panel, each row showing that panel's
# headline state, so a glance here answers "what's my volume / am I
# online / is Bluetooth on" without opening anything. Every query below
# is local and cheap (no scan, no network), re-run each time this menu
# comes back into view so returning from a submenu shows what it changed.

source "$HOME/.config/hypr/scripts/menu-lib.sh"

audio_state() {
    local v
    v=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null) || return
    [[ "$v" == *MUTED* ]] && { echo "muted"; return; }
    awk '{printf "%d%%", $2 * 100 + 0.5}' <<<"$v"
}

network_state() {
    local type conn
    IFS=: read -r type conn < <(nmcli -t -f TYPE,NAME connection show --active 2>/dev/null \
        | grep -v '^loopback:' | head -n1)
    case "$type" in
        802-11-wireless) echo "$conn" ;;
        802-3-ethernet) echo "Ethernet" ;;
        "") echo "offline" ;;
        *) echo "$conn" ;;
    esac
}

bluetooth_state() {
    command -v bluetoothctl >/dev/null || { echo "unavailable"; return; }
    bluetoothctl show 2>/dev/null | grep -q "Powered: yes" || { echo "off"; return; }
    local n
    n=$(bluetoothctl devices Connected 2>/dev/null | grep -c '^Device ')
    ((n > 0)) && echo "$n connected" || echo "on"
}

# get-updates reads fwupd's local metadata cache, no network: 0 means
# updates are available, 2 means there's nothing to do.
firmware_state() {
    command -v fwupdmgr >/dev/null || return
    timeout 5 fwupdmgr get-updates --no-unreported-check >/dev/null 2>&1
    case $? in
        0) echo "updates available" ;;
        2) echo "up to date" ;;
    esac
}

# Power Profile only exists on laptops: tlp-pd (and so tlpctl) is
# installed only when the installer detects a laptop chassis.
selected=""
while :; do
    menu_reset
    menu_add audio "Audio" volume-2.svg "$(audio_state)"
    menu_add network "Network" wifi.svg "$(network_state)"
    menu_add bluetooth "Bluetooth" bluetooth.svg "$(bluetooth_state)"
    command -v tlpctl >/dev/null && menu_add power-profile "Power Profile" battery-2.svg "$(tlpctl get 2>/dev/null)"
    menu_add firmware "Firmware" cpu.svg "$(firmware_state)"

    menu_show system "" "$selected" || break
    selected="$MENU_ID"
    case "$MENU_ID" in
        audio) menu_sub audio-menu.sh ;;
        network) menu_sub network-menu.sh ;;
        bluetooth) menu_sub bluetooth-menu.sh ;;
        power-profile) menu_sub power-profile-menu.sh ;;
        firmware) menu_sub fwupd-menu.sh ;;
    esac
done
