#!/bin/bash
# Combined audio/network/bluetooth status for the custom/system waybar module.

vol_raw=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
volpct=$(echo "$vol_raw" | awk '{printf "%d", $2*100}')
if echo "$vol_raw" | grep -q MUTED; then
    icon="󰝟"
else
    icon="󰕾"
fi

net_dev=$(nmcli -t -f DEVICE,TYPE,STATE dev status 2>/dev/null | awk -F: '$3=="connected"{print $1" ("$2")"; exit}')
[ -n "$net_dev" ] || net_dev="disconnected"

if [ -d /sys/class/bluetooth ] && command -v bluetoothctl >/dev/null; then
    if bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
        bt_status="on"
    else
        bt_status="off"
    fi
else
    bt_status="no controller"
fi

printf '{"text": "%s %s%%", "tooltip": "Volume: %s%%\\nNetwork: %s\\nBluetooth: %s"}\n' \
    "$icon" "$volpct" "$volpct" "$net_dev" "$bt_status"
