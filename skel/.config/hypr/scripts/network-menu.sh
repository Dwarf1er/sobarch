#!/bin/bash

source "$HOME/.config/hypr/scripts/notify-progress.sh"

ICONS="$HOME/.config/sobarch/icons"

# wifi: same icon system-menu.sh's own "Network" entry uses.
TITLE="sobarch: network"

# notify_on_fail runs an nmcli action and, only if it fails, surfaces
# its own stderr as a critical notification (nmcli puts error text on
# stderr with a matching exit code).
notify_on_fail() {
    local err
    err=$("$@" 2>&1 >/dev/null)
    [ -n "$err" ] && notify-send -u critical -i "$ICONS/wifi.svg" "$TITLE" "$err"
}

# Loops back to this same picker after every action instead of exiting,
# so e.g. checking Wi-Fi networks then toggling Wi-Fi doesn't need the
# keybind re-invoked each time. Only an empty selection (Escape) breaks
# out. --minimal-lines added since every row now carries an icon (see
# wallpaper-menu.sh's own comment on the empty-leftover-row
# icon-duplication bug this avoids).
while choice=$(printf '%s\0icon\x1f%s\n' \
    "Wi-Fi Networks" "$ICONS/wifi.svg" \
    "Toggle Wi-Fi" "$ICONS/power.svg" \
    "Disconnect" "$ICONS/wifi-off.svg" \
    "Forget Network" "$ICONS/trash.svg" \
    "Copy IP Address" "$ICONS/clipboard.svg" \
    "Share Wi-Fi QR" "$ICONS/qrcode.svg" \
    | fuzzel --dmenu --prompt "network: " --lines=6 --line-height=23 --minimal-lines)
    [ -n "$choice" ]
do
    case "$choice" in
        "Wi-Fi Networks")
            id=$(notify_progress normal "$TITLE" "Scanning for Wi-Fi networks..." 0 persist "$ICONS/wifi.svg")
            # SSID may itself contain a colon in rare cases, so the
            # split takes the last two fields as signal/security and
            # rejoins everything before that as the SSID, rather than
            # assuming SSID is exactly field 1.
            networks=$(nmcli -e no -t -f SSID,SIGNAL,SECURITY dev wifi list --rescan yes | awk -F: '
                NF < 3 { next }
                {
                    security = $NF
                    signal = $(NF - 1)
                    ssid = $1
                    for (i = 2; i <= NF - 2; i++) ssid = ssid ":" $i
                    if (ssid == "" || seen[ssid]++) next
                    printf "%-22s %3s%%  %s\t%s\n", ssid, signal, (security == "" ? "Open" : security), ssid
                }')
            notify_progress normal "$TITLE" "Scan complete." "$id" "" "$ICONS/wifi.svg" >/dev/null
            line=$(printf '%s\n' "$networks" | fuzzel --dmenu --with-nth=1 --prompt "wifi: " --width=45)
            [ -n "$line" ] || continue
            ssid="${line##*$'\t'}"
            if nmcli -e no -t -f NAME connection show | grep -qxF "$ssid"; then
                notify_on_fail nmcli connection up "$ssid"
            else
                pass=$(fuzzel --dmenu --password --prompt "password: ")
                notify_on_fail nmcli dev wifi connect "$ssid" password "$pass"
            fi
            ;;
        "Toggle Wi-Fi")
            if [ "$(nmcli radio wifi)" = "enabled" ]; then
                notify_on_fail nmcli radio wifi off
            else
                notify_on_fail nmcli radio wifi on
            fi
            ;;
        "Disconnect")
            dev=$(nmcli -t -f DEVICE,TYPE dev status | awk -F: '$2=="wifi"{print $1; exit}')
            [ -n "$dev" ] && notify_on_fail nmcli dev disconnect "$dev"
            ;;
        "Forget Network")
            name=$(nmcli -e no -t -f NAME connection show | sort -f | fuzzel --dmenu --prompt "forget: ")
            [ -n "$name" ] && notify_on_fail nmcli connection delete "$name"
            ;;
        "Copy IP Address")
            dev=$(nmcli -t -f DEVICE,STATE dev status | awk -F: '$2=="connected"{print $1; exit}')
            [ -n "$dev" ] && nmcli -t -f IP4.ADDRESS dev show "$dev" | cut -d: -f2 | cut -d/ -f1 | wl-copy
            ;;
        "Share Wi-Fi QR")
            conn=$(nmcli -t -f NAME,TYPE connection show --active | awk -F: '$2=="802-11-wireless"{print $1; exit}')
            [ -n "$conn" ] || continue
            ssid=$(nmcli -g 802-11-wireless.ssid connection show "$conn")
            psk=$(nmcli -s -g 802-11-wireless-security.psk connection show "$conn")
            if [ -n "$psk" ]; then
                payload="WIFI:T:WPA;S:${ssid};P:${psk};;"
            else
                payload="WIFI:T:nopass;S:${ssid};;"
            fi
            # Rendered as ASCII directly in a fuzzel pane instead of
            # imv/PNG, to match the small centered floating look fuzzel
            # gets for free (a wlroots layer-shell surface, unlike a
            # real window, which would need its own float+size+center
            # window rule and would still tile/fullscreen by default).
            # --mesg (with --mesg-mode=expand, which sizes the window to
            # the message instead of wrapping it) replaces the old
            # --width/--lines character-count fudge factor entirely:
            # fuzzel measures its own message text directly instead of
            # this script guessing at column counts, so it can't drift
            # out of alignment for a different SSID/password length or
            # QR version the way the old estimate could.
            # --minimal-lines drops the empty dmenu list area below the
            # message, since this picker has no real entries -- it's
            # message-only, dismissed with any key.
            qr_text=$(qrencode -t UTF8 "$payload" | sed 's/^/ /')
            fuzzel --dmenu --hide-prompt --minimal-lines \
                --mesg="$qr_text" --mesg-mode=expand </dev/null
            ;;
    esac
done
