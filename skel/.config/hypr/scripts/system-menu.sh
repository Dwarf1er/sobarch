#!/bin/bash
# System overview; each row shows its panel's state. Queries are local
# and re-run whenever the menu comes back into view.

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

# get-updates reads the local cache: 0 = updates available, 2 = none.
firmware_state() {
    command -v fwupdmgr >/dev/null || return
    timeout 5 fwupdmgr get-updates --no-unreported-check >/dev/null 2>&1
    case $? in
        0) echo "updates available" ;;
        2) echo "up to date" ;;
    esac
}

displays_state() {
    local n
    n=$(hyprctl monitors 2>/dev/null | grep -c '^Monitor')
    ((n == 1)) && echo "1 monitor" || echo "$n monitors"
}

vpn_state() {
    local n
    n=$(nmcli -t -f TYPE connection show --active 2>/dev/null | grep -c '^wireguard$')
    ((n > 0)) && echo "$n on" || echo "off"
}

remote_access_state() { systemctl --user is-active --quiet app-dev.lizardbyte.app.Sunshine.service && echo "on" || echo "off"; }

recording_state() { pgrep -x wf-recorder >/dev/null && echo "recording"; }

# tlpctl is only installed on laptops.
selected=""
while :; do
    menu_reset
    menu_add audio "Audio" volume-2.svg "$(audio_state)"
    menu_add network "Network" wifi.svg "$(network_state)"
    menu_add bluetooth "Bluetooth" bluetooth.svg "$(bluetooth_state)"
    command -v tlpctl >/dev/null && menu_add power-profile "Power Profile" battery-2.svg "$(tlpctl get 2>/dev/null)"
    command -v wg >/dev/null && menu_add vpn "VPN" world.svg "$(vpn_state)"
    command -v sunshine >/dev/null && menu_add remote-access "Remote Access" plug.svg "$(remote_access_state)"
    menu_add displays "Displays" devices.svg "$(displays_state)"
    command -v wf-recorder >/dev/null && menu_add recording "Screen Recording" movie.svg "$(recording_state)"
    menu_add firmware "Firmware" cpu.svg "$(firmware_state)"

    menu_show system "" "$selected" || break
    selected="$MENU_ID"
    case "$MENU_ID" in
        audio) menu_sub audio-menu.sh ;;
        network) menu_sub network-menu.sh ;;
        bluetooth) menu_sub bluetooth-menu.sh ;;
        power-profile) menu_sub power-profile-menu.sh ;;
        vpn) menu_sub wireguard-menu.sh ;;
        remote-access) menu_sub remote-access-menu.sh ;;
        displays) menu_sub displays-menu.sh ;;
        recording) menu_sub recording-menu.sh ;;
        firmware) menu_sub fwupd-menu.sh ;;
    esac
done
