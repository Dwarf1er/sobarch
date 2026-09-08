#!/bin/bash

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
        ssid=$(nmcli -e no -t -f SSID dev wifi list --rescan yes | awk 'NF && !seen[$0]++' | fuzzel --dmenu --prompt "wifi: ")
        [ -n "$ssid" ] || exit 0
        if nmcli -e no -t -f NAME connection show | grep -qxF "$ssid"; then
            err=$(nmcli connection up "$ssid" 2>&1 >/dev/null)
        else
            pass=$(fuzzel --dmenu --password --prompt "password: ")
            err=$(nmcli dev wifi connect "$ssid" password "$pass" 2>&1 >/dev/null)
        fi
        [ -n "$err" ] && notify-send "Network" "$err"
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
        name=$(nmcli -e no -t -f NAME connection show | fuzzel --dmenu --prompt "forget: ")
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
        # Rendered as ASCII directly in a fuzzel pane instead of imv/PNG,
        # to match the small centered floating look fuzzel gets for free
        # (a wlroots layer-shell surface, unlike a real window, which
        # would need its own float+size+center window rule and would
        # still tile/fullscreen by default). --width is fuzzel's own
        # *estimate* of character count (fuzzel.ini(5)), not a measurement
        # of the actual rendered line, so it doesn't land exactly on the
        # real column count for this font; "cols-2" is a fudge factor
        # found by testing against one real SSID/password pair, not
        # derived from a formula, and only confirmed for that QR size --
        # if a much longer/shorter SSID+password (different QR version)
        # ever looks off-center again, this is the first thing to
        # re-check. horizontal-pad also only pads one side (a fuzzel
        # quirk, not configurable), hence the single leading space
        # prepended to every line instead of using the pad itself.
        qr_text=$(qrencode -t UTF8 "$payload" | sed 's/^/ /')
        cols=$(head -1 <<<"$qr_text" | wc -L)
        rows=$(wc -l <<<"$qr_text")
        fuzzel --dmenu --hide-prompt \
            --horizontal-pad=0 --vertical-pad=3 \
            --line-height=18 --letter-spacing=0 \
            --width=$((cols - 2)) --lines="$rows" <<<"$qr_text"
        ;;
esac
