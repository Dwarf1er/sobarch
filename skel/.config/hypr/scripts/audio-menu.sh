#!/bin/bash

# md-volume_high: same icon this menu's own "Toggle Output Mute" entry
# (and system-menu.sh's "Audio" entry) already use.
TITLE=$'\U000F057E'"  sobarch: audio"

# notify_on_fail runs a wpctl/pactl action and, only if it fails,
# surfaces its own stderr as a critical notification: same convention
# network-menu.sh uses for nmcli (both tools already put their error
# text on stderr with a matching exit code, unlike bluetoothctl).
notify_on_fail() {
    local err
    err=$("$@" 2>&1 >/dev/null)
    [ -n "$err" ] && notify-send -u critical "$TITLE" "$err"
}

choice=$(printf "%s\n" \
    "󰕾  Toggle Output Mute" \
    "󰍬  Toggle Mic Mute" \
    "󰕾  Volume +5%" \
    "󰕾  Volume -5%" \
    "󰋋  Switch Output Device" \
    "󰍬  Switch Input Device" \
    "󰕾  Per-App Volume" \
    | fuzzel --dmenu --prompt "audio: ")

case "$choice" in
    "󰕾  Toggle Output Mute")
        notify_on_fail wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        ;;
    "󰍬  Toggle Mic Mute")
        notify_on_fail wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
        ;;
    "󰕾  Volume +5%")
        notify_on_fail wpctl set-volume --limit 1.0 @DEFAULT_AUDIO_SINK@ 5%+
        ;;
    "󰕾  Volume -5%")
        notify_on_fail wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
        ;;
    "󰋋  Switch Output Device")
        sink=$(pactl list sinks short | awk '{print $2}' | fuzzel --dmenu --prompt "output: ")
        [ -n "$sink" ] && notify_on_fail pactl set-default-sink "$sink"
        ;;
    "󰍬  Switch Input Device")
        source=$(pactl list sources short | awk '$2 !~ /\.monitor$/ {print $2}' | fuzzel --dmenu --prompt "input: ")
        [ -n "$source" ] && notify_on_fail pactl set-default-source "$source"
        ;;
    "󰕾  Per-App Volume")
        app=$(pactl list sink-inputs | awk -F'"' '/application.name = /{print $2}' | sort -u | fuzzel --dmenu --prompt "app: ")
        [ -n "$app" ] || exit 0
        id=$(pactl list sink-inputs | awk -v app="$app" '
            /Sink Input #/ {input_id=$3; sub("#","",input_id)}
            $0 ~ "application.name = \"" app "\"" {print input_id; exit}
        ')
        [ -n "$id" ] || exit 0
        action=$(printf "%s\n" "󰖁  Mute" "󰕾  Unmute" "󰕾  Volume +5%" "󰕾  Volume -5%" | fuzzel --dmenu --prompt "$app: ")
        case "$action" in
            "󰖁  Mute") notify_on_fail pactl set-sink-input-mute "$id" 1 ;;
            "󰕾  Unmute") notify_on_fail pactl set-sink-input-mute "$id" 0 ;;
            "󰕾  Volume +5%") notify_on_fail pactl set-sink-input-volume "$id" +5% ;;
            "󰕾  Volume -5%") notify_on_fail pactl set-sink-input-volume "$id" -5% ;;
        esac
        ;;
esac
