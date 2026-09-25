#!/bin/bash

ICONS="$HOME/.config/sobarch/icons"

# volume-2: same icon system-menu.sh's own "Audio" entry uses.
TITLE="sobarch: audio"

# notify_on_fail runs a wpctl/pactl action and, only if it fails,
# surfaces its own stderr as a critical notification: same convention
# network-menu.sh uses for nmcli (both tools already put their error
# text on stderr with a matching exit code, unlike bluetoothctl).
notify_on_fail() {
    local err
    err=$("$@" 2>&1 >/dev/null)
    [ -n "$err" ] && notify-send -u critical -i "$ICONS/volume-2.svg" "$TITLE" "$err"
}

# Loops back to this same picker after every action instead of exiting,
# so a run of volume nudges or a mute/unmute doesn't need the keybind
# re-invoked each time. Only an empty selection (Escape, or fuzzel's
# own search coming up empty) breaks out. --minimal-lines added since
# every row now carries an icon (see wallpaper-menu.sh's own comment on
# the empty-leftover-row icon-duplication bug this avoids).
while choice=$(printf '%s\0icon\x1f%s\n' \
    "Toggle Output Mute" "$ICONS/volume-off.svg" \
    "Toggle Mic Mute" "$ICONS/microphone-off.svg" \
    "Volume +5%" "$ICONS/volume-2.svg" \
    "Volume -5%" "$ICONS/volume.svg" \
    "Switch Output Device" "$ICONS/device-speaker.svg" \
    "Switch Input Device" "$ICONS/microphone.svg" \
    "Per-App Volume" "$ICONS/apps.svg" \
    | fuzzel --dmenu --prompt "audio: " --lines=7 --line-height=20 --minimal-lines)
    [ -n "$choice" ]
do
    case "$choice" in
        "Toggle Output Mute")
            notify_on_fail wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
            ;;
        "Toggle Mic Mute")
            notify_on_fail wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
            ;;
        "Volume +5%")
            notify_on_fail wpctl set-volume --limit 1.0 @DEFAULT_AUDIO_SINK@ 5%+
            ;;
        "Volume -5%")
            notify_on_fail wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
            ;;
        "Switch Output Device")
            sink=$(pactl list sinks short | awk '{print $2}' | sort -f | fuzzel --dmenu --prompt "output: ")
            [ -n "$sink" ] && notify_on_fail pactl set-default-sink "$sink"
            ;;
        "Switch Input Device")
            source=$(pactl list sources short | awk '$2 !~ /\.monitor$/ {print $2}' | sort -f | fuzzel --dmenu --prompt "input: ")
            [ -n "$source" ] && notify_on_fail pactl set-default-source "$source"
            ;;
        "Per-App Volume")
            app=$(pactl list sink-inputs | awk -F'"' '/application.name = /{print $2}' | sort -u | fuzzel --dmenu --prompt "app: ")
            [ -n "$app" ] || continue
            id=$(pactl list sink-inputs | awk -v app="$app" '
                /Sink Input #/ {input_id=$3; sub("#","",input_id)}
                $0 ~ "application.name = \"" app "\"" {print input_id; exit}
            ')
            [ -n "$id" ] || continue
            action=$(printf '%s\0icon\x1f%s\n' "Mute" "$ICONS/volume-off.svg" "Unmute" "$ICONS/volume-2.svg" "Volume +5%" "$ICONS/volume-2.svg" "Volume -5%" "$ICONS/volume.svg" | fuzzel --dmenu --prompt "$app: " --minimal-lines)
            case "$action" in
                "Mute") notify_on_fail pactl set-sink-input-mute "$id" 1 ;;
                "Unmute") notify_on_fail pactl set-sink-input-mute "$id" 0 ;;
                "Volume +5%") notify_on_fail pactl set-sink-input-volume "$id" +5% ;;
                "Volume -5%") notify_on_fail pactl set-sink-input-volume "$id" -5% ;;
            esac
            ;;
    esac
done
