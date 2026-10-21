#!/bin/bash
# Volume, mic, brightness and do-not-disturb: change the value, then show a
# mako toast that replaces itself.
#
#   osd.sh volume-up|volume-down|mute|mic-mute|dnd|brightness-up|brightness-down

ICONS="$HOME/.config/sobarch/icons"

show() { # ICON TITLE BODY [PERCENT]
    local hint=()
    [ -n "${4:-}" ] && hint=(-h "int:value:$4")
    notify-send -a osd -c osd -t 1200 -i "$ICONS/$1" \
        -h string:x-canonical-private-synchronous:osd "${hint[@]}" "$2" "$3"
}

sink=@DEFAULT_AUDIO_SINK@
source=@DEFAULT_AUDIO_SOURCE@

show_volume() {
    local v pct
    v=$(wpctl get-volume "$sink") || return
    if [[ "$v" == *MUTED* ]]; then
        show volume-off.svg "Volume" "Muted" 0
        return
    fi
    pct=$(awk '{printf "%d", $2 * 100 + 0.5}' <<<"$v")
    show volume-2.svg "Volume" "$pct%" "$pct"
}

case "${1:-}" in
    volume-up) wpctl set-volume --limit 1.0 "$sink" 5%+ && show_volume ;;
    volume-down) wpctl set-volume "$sink" 5%- && show_volume ;;
    mute) wpctl set-mute "$sink" toggle && show_volume ;;
    mic-mute)
        wpctl set-mute "$source" toggle || exit
        if wpctl get-volume "$source" | grep -q MUTED; then
            show microphone-off.svg "Microphone" "Muted"
        else
            show microphone.svg "Microphone" "On"
        fi
        ;;
    dnd)
        makoctl mode -t do-not-disturb >/dev/null || exit
        if makoctl mode | grep -qx do-not-disturb; then
            show bell-off.svg "Do Not Disturb" "On"
        else
            show bell.svg "Do Not Disturb" "Off"
        fi
        ;;
    brightness-up | brightness-down)
        step="10%+"
        [ "$1" = brightness-down ] && step="10%-"
        brightnessctl s "$step" >/dev/null || exit
        pct=$(brightnessctl -m | awk -F, '{gsub("%", "", $4); print $4}')
        show sun.svg "Brightness" "$pct%" "$pct"
        ;;
    *)
        echo "osd.sh: unknown action '${1:-}'" >&2
        exit 2
        ;;
esac
