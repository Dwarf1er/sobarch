#!/bin/bash
# Network panel. Wi-Fi rows only appear when a Wi-Fi device exists.

source "$HOME/.config/hypr/scripts/menu-lib.sh"

MENU_TITLE="sobarch: network"
MENU_ICON="wifi.svg"

wifi_dev=$(nmcli -t -f DEVICE,TYPE dev status 2>/dev/null | awk -F: '$2 == "wifi" { print $1; exit }')

# NAME<\037>TYPE<\037>DEVICE of the first active non-loopback connection.
# -e no leaves names unescaped, so TYPE and DEVICE are read from the end.
primary() {
    nmcli -e no -t -f NAME,TYPE,DEVICE connection show --active 2>/dev/null | awk -F: '
        $(NF - 1) != "loopback" {
            name = $1; for (i = 2; i <= NF - 2; i++) name = name ":" $i
            print name "\037" $(NF - 1) "\037" $NF; exit
        }'
}

ip_of() { nmcli -g IP4.ADDRESS dev show "$1" 2>/dev/null | head -n1 | cut -d/ -f1; }

# IN-USE<\037>SSID<\037>SIGNAL<\037>SECURITY per network, strongest first.
# SSIDs can contain colons, so fixed fields are read from both ends.
scan_results() {
    nmcli -e no -t -f IN-USE,SSID,SIGNAL,BARS,SECURITY dev wifi list --rescan yes 2>/dev/null | awk -F: '
        NF < 5 { next }
        {
            ssid = $2; for (i = 3; i <= NF - 3; i++) ssid = ssid ":" $i
            if (ssid == "" || seen[ssid]++) next
            print $1 "\037" ssid "\037" $(NF - 2) "\037" $NF
        }'
}

# A failed join leaves a half-made profile behind; delete it so the next
# try asks for the password again.
join_new() {
    local ssid="$1" security="$2" pass
    if [ -n "$security" ] && [ "$security" != "--" ]; then
        pass=$(menu_input password "Password for “$ssid”" password) || return
        menu_progress "Connecting to $ssid..." "Connected to $ssid." \
            nmcli dev wifi connect "$ssid" password "$pass" ifname "$wifi_dev" ||
            nmcli connection delete id "$ssid" >/dev/null 2>&1
    else
        menu_progress "Connecting to $ssid..." "Connected to $ssid." \
            nmcli dev wifi connect "$ssid" ifname "$wifi_dev"
    fi
}

# menu_progress discards a successful command's stdout, so write to a file.
scan_to() { scan_results >"$1"; }

wifi_menu() {
    local in_use ssid signal security results
    local -A sec
    results=$(mktemp)
    menu_progress "Scanning for Wi-Fi networks..." "Scan complete." scan_to "$results"
    menu_reset
    # nmcli's BARS glyphs are illegible at this font size.
    while IFS=$'\037' read -r in_use ssid signal security; do
        sec["$ssid"]="$security"
        if [ "$in_use" = "*" ]; then
            menu_add "$ssid" "$ssid" wifi.svg "connected"
        elif [ -z "$security" ] || [ "$security" = "--" ]; then
            menu_add "$ssid" "$ssid" wifi.svg "open · $signal%"
        else
            menu_add "$ssid" "$ssid" wifi.svg "$signal%"
        fi
    done <"$results"
    rm -f "$results"
    if ((${#MENU_IDS[@]} == 0)); then
        menu_notify "No Wi-Fi networks found."
        return
    fi
    menu_show wi-fi || return
    ssid="$MENU_ID"
    if nmcli -e no -t -f NAME connection show | grep -qxF "$ssid"; then
        menu_progress "Connecting to $ssid..." "Connected to $ssid." nmcli connection up id "$ssid"
    else
        join_new "$ssid" "${sec[$ssid]}"
    fi
}

# Every saved profile except loopback; Enter toggles it, Alt+1 forgets.
saved_menu() {
    local selected="" name type active icon
    while :; do
        menu_reset
        while IFS=$'\037' read -r name type active; do
            case "$type" in
                802-11-wireless) icon=wifi.svg ;;
                802-3-ethernet) icon=plug.svg ;;
                *) icon=world.svg ;;
            esac
            menu_add "$name" "$name" "$icon" "$([ "$active" = yes ] && echo active)"
        done < <(nmcli -e no -t -f NAME,TYPE,ACTIVE connection show 2>/dev/null | awk -F: '
            $(NF - 1) != "loopback" {
                name = $1; for (i = 2; i <= NF - 2; i++) name = name ":" $i
                print name "\037" $(NF - 1) "\037" $NF
            }' | sort -f)
        menu_show "saved" "↵ connect/disconnect · Alt+1 forget" "$selected" || return
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
            1) confirm "Forget “$name”? Its saved password is deleted too." Forget &&
                menu_run nmcli connection delete id "$name" ;;
        esac
    done
}

# QR code drawn as text in a fuzzel message. line-height=16 keeps the
# half-block rows seamless.
share_qr() {
    local conn="$1" ssid psk payload
    ssid=$(nmcli -g 802-11-wireless.ssid connection show "$conn")
    psk=$(nmcli -s -g 802-11-wireless-security.psk connection show "$conn")
    if [ -n "$psk" ]; then
        payload="WIFI:T:WPA;S:${ssid};P:${psk};;"
    else
        payload="WIFI:T:nopass;S:${ssid};;"
    fi
    local text_color
    text_color=$(sed -n 's/^text=//p' "$HOME/.config/fuzzel/colors.ini" 2>/dev/null)
    fuzzel --dmenu --hide-prompt --minimal-lines --mesg-mode=expand --line-height=16 \
        ${text_color:+--message-color="$text_color"} \
        --mesg="Scan to join “$ssid”"$'\n\n'"$(qrencode -t UTF8 "$payload" | sed 's/^/ /')" </dev/null
}

selected=""
while :; do
    IFS=$'\037' read -r conn type dev < <(primary)
    ip=""
    [ -n "$dev" ] && ip=$(ip_of "$dev")
    case "$type" in
        802-11-wireless) mesg="Connected to $conn" ;;
        802-3-ethernet) mesg="Connected via Ethernet" ;;
        "") mesg="Not connected" ;;
        *) mesg="Connected to $conn" ;;
    esac
    saved=$(nmcli -t -f TYPE connection show 2>/dev/null | grep -vc '^loopback$')

    menu_reset
    if [ -n "$wifi_dev" ]; then
        if [ "$(nmcli radio wifi)" = enabled ]; then
            menu_add wifi "Wi-Fi Networks" wifi.svg
            menu_add radio "Turn Wi-Fi Off" power.svg
        else
            menu_add radio "Turn Wi-Fi On" power.svg
        fi
        if [ "$type" = 802-11-wireless ]; then
            menu_add disconnect "Disconnect" wifi-off.svg
            menu_add qr "Share Wi-Fi" qrcode.svg
        fi
    fi
    menu_add saved "Saved Networks" world.svg "$saved saved"
    [ -n "$ip" ] && menu_add ip "Copy IP Address" clipboard.svg "$ip"

    menu_show network "$mesg" "$selected" || break
    selected="$MENU_ID"
    case "$MENU_ID" in
        wifi) wifi_menu ;;
        radio)
            if [ "$(nmcli radio wifi)" = enabled ]; then
                menu_run nmcli radio wifi off
            else
                menu_run nmcli radio wifi on
            fi
            ;;
        disconnect) menu_run nmcli dev disconnect "$wifi_dev" ;;
        qr) share_qr "$conn" ;;
        saved) saved_menu ;;
        ip) printf '%s' "$ip" | wl-copy && menu_notify "Copied $ip to the clipboard." ;;
    esac
done
