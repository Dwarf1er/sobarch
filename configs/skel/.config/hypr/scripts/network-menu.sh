#!/bin/bash
# Fuzzel-based network menu, replaces nmgui.

choice=$(printf "%s\n" \
    "󰤨  Wi-Fi Networks" \
    "⏻  Toggle Wi-Fi" \
    "󰖪  Disconnect" \
    "󰅙  Forget Network" \
    "󰆏  Copy IP Address" \
    "󰍁  Share Wi-Fi QR" \
    | fuzzel --dmenu --prompt "network: ")

case "$choice" in
    "󰤨  Wi-Fi Networks")
        ssid=$(nmcli -t -f SSID dev wifi list --rescan yes | awk 'NF && !seen[$0]++' | fuzzel --dmenu --prompt "wifi: ")
        [ -n "$ssid" ] || exit 0
        if nmcli -t -f NAME connection show | grep -qxF "$ssid"; then
            nmcli connection up "$ssid"
        else
            pass=$(fuzzel --dmenu --password --prompt "password: ")
            nmcli dev wifi connect "$ssid" password "$pass"
        fi
        ;;
    "⏻  Toggle Wi-Fi")
        if [ "$(nmcli radio wifi)" = "enabled" ]; then
            nmcli radio wifi off
        else
            nmcli radio wifi on
        fi
        ;;
    "󰖪  Disconnect")
        dev=$(nmcli -t -f DEVICE,TYPE dev status | awk -F: '$2=="wifi"{print $1; exit}')
        [ -n "$dev" ] && nmcli dev disconnect "$dev"
        ;;
    "󰅙  Forget Network")
        name=$(nmcli -t -f NAME connection show | fuzzel --dmenu --prompt "forget: ")
        [ -n "$name" ] && nmcli connection delete "$name"
        ;;
    "󰆏  Copy IP Address")
        dev=$(nmcli -t -f DEVICE,STATE dev status | awk -F: '$2=="connected"{print $1; exit}')
        [ -n "$dev" ] && nmcli -t -f IP4.ADDRESS dev show "$dev" | cut -d: -f2 | cut -d/ -f1 | wl-copy
        ;;
    "󰍁  Share Wi-Fi QR")
        conn=$(nmcli -t -f NAME,TYPE connection show --active | awk -F: '$2=="802-11-wireless"{print $1; exit}')
        [ -n "$conn" ] || exit 0
        ssid=$(nmcli -g 802-11-wireless.ssid connection show "$conn")
        psk=$(nmcli -s -g 802-11-wireless-security.psk connection show "$conn")
        if [ -n "$psk" ]; then
            payload="WIFI:T:WPA;S:${ssid};P:${psk};;"
        else
            payload="WIFI:T:nopass;S:${ssid};;"
        fi
        qr=$(mktemp --suffix=.png)
        qrencode -o "$qr" "$payload"
        imv "$qr"
        rm -f "$qr"
        ;;
esac
