#!/bin/bash
# Audio control panel: output volume as a meter in the header, mute
# toggles named for what they'll do next, current output/input devices
# shown inline, and per-app volume for whatever is playing. Stays open
# after every action (cursor kept in place), so pressing Enter on
# "Volume Up" a few times works like a stepper.

source "$HOME/.config/hypr/scripts/menu-lib.sh"

MENU_TITLE="sobarch: audio"
MENU_ICON="volume-2.svg"

# "40" for a 40% node, "" if unreadable; wpctl reports a 0.00-1.00+ float.
volume_of() {
    wpctl get-volume "$1" 2>/dev/null | awk '{printf "%d", $2 * 100 + 0.5}'
}

is_muted() { wpctl get-volume "$1" 2>/dev/null | grep -q MUTED; }

# "▮▮▮▮▮▮▮▯▯▯▯▯▯▯▯▯▯▯" for a 0-100 level, 18 cells wide.
meter() {
    local filled=$((($1 * 18 + 50) / 100)) bar="" i
    ((filled > 18)) && filled=18
    for ((i = 0; i < 18; i++)); do
        ((i < filled)) && bar+="▮" || bar+="▯"
    done
    printf '%s' "$bar"
}

# NAME<\037>NICK per sink or source, monitors left out. node.nick is
# the short human name ("LS27AG30x", "fifine Microphone") where
# device.description is the long chipset one ("Navi 21/23 HDMI/DP
# Audio Controller Digital Stereo (HDMI) [LS27AG30x]").
nodes() {
    pactl list "$1" 2>/dev/null | awk '
        function val() { v = $0; sub(/^[^"]*"/, "", v); sub(/"$/, "", v); return v }
        function emit() { if (name != "" && name !~ /\.monitor$/) print name "\037" (nick != "" ? nick : desc) }
        /^(Sink|Source) #/ { emit(); name = nick = desc = "" }
        /^\tName: / { name = substr($0, index($0, ":") + 2) }
        /^\t\tnode\.nick = / { nick = val() }
        /^\t\tdevice\.description = / { desc = val() }
        END { emit() }'
}

nick_of() {
    local default="$1" name nick
    while IFS=$'\037' read -r name nick; do
        [ "$name" = "$default" ] && { printf '%s' "$nick"; return; }
    done
}

# Picker for the default sink or source; returns to the panel after a
# choice, since there's nothing more to do here once one is picked.
device_menu() {
    local kind="$1" current name nick icon
    if [ "$kind" = sinks ]; then
        current=$(pactl get-default-sink) icon=device-speaker.svg
    else
        current=$(pactl get-default-source) icon=microphone.svg
    fi
    menu_reset
    while IFS=$'\037' read -r name nick; do
        menu_add "$name" "$nick" "$icon" "$([ "$name" = "$current" ] && echo active)"
    done < <(nodes "$kind")
    menu_show "$([ "$kind" = sinks ] && echo output || echo input)" "" "$current" || return
    if [ "$kind" = sinks ]; then
        menu_run pactl set-default-sink "$MENU_ID"
    else
        menu_run pactl set-default-source "$MENU_ID"
    fi
}

# ID<\037>NAME<\037>VOLUME<\037>MUTED<\037>ICON per playing stream.
streams() {
    pactl list sink-inputs 2>/dev/null | awk '
        function val() { v = $0; sub(/^[^"]*"/, "", v); sub(/"$/, "", v); return v }
        function emit() { if (id != "") print id "\037" (app != "" ? app : "Unknown") "\037" vol "\037" mute "\037" icon }
        /^Sink Input #/ { emit(); id = substr($3, 2); app = vol = mute = icon = "" }
        /^\tMute: / { mute = ($2 == "yes") }
        /^\tVolume: / { for (i = 1; i <= NF; i++) if ($i ~ /%$/) { vol = $i + 0; break } }
        /^\t\tapplication\.name = / { app = val() }
        /^\t\tapplication\.icon_name = / { icon = val() }
        END { emit() }'
}

# One app's own volume panel, re-read every pass; leaves by itself once
# the stream ends.
app_menu() {
    local id="$1" sid name vol mute icon selected="" found
    while :; do
        found=0
        while IFS=$'\037' read -r sid name vol mute icon; do
            [ "$sid" = "$id" ] && { found=1; break; }
        done < <(streams)
        ((found)) || return
        menu_reset
        menu_add up "Volume Up" volume-2.svg
        menu_add down "Volume Down" volume.svg
        if ((mute)); then
            menu_add mute "Unmute" volume-2.svg
        else
            menu_add mute "Mute" volume-off.svg
        fi
        menu_show "$name" "$(meter "$((mute ? 0 : vol))")  $( ((mute)) && echo muted || echo "$vol%")" "$selected" || return
        selected="$MENU_ID"
        case "$MENU_ID" in
            # Capped at 100%, same as the output's own --limit 1.0.
            up) menu_run pactl set-sink-input-volume "$id" "$((vol + 5 > 100 ? 100 : vol + 5))%" ;;
            down) menu_run pactl set-sink-input-volume "$id" -5% ;;
            mute) menu_run pactl set-sink-input-mute "$id" toggle ;;
        esac
    done
}

apps_menu() {
    local id name vol mute icon
    menu_reset
    while IFS=$'\037' read -r id name vol mute icon; do
        menu_add "$id" "$name" "$icon,apps.svg" "$( ((mute)) && echo muted || echo "$vol%")"
    done < <(streams)
    menu_show apps || return
    app_menu "$MENU_ID"
}

selected=""
while :; do
    sink=@DEFAULT_AUDIO_SINK@ src=@DEFAULT_AUDIO_SOURCE@
    vol=$(volume_of $sink)
    stream_count=$(pactl list short sink-inputs 2>/dev/null | wc -l)

    menu_reset
    menu_add up "Volume Up" volume-2.svg
    menu_add down "Volume Down" volume.svg
    if is_muted $sink; then
        menu_add mute "Unmute" volume-2.svg
        mesg="$(meter 0)  muted"
    else
        menu_add mute "Mute" volume-off.svg
        mesg="$(meter "${vol:-0}")  ${vol:-0}%"
    fi
    if is_muted $src; then
        menu_add mic "Unmute Microphone" microphone.svg
    else
        menu_add mic "Mute Microphone" microphone-off.svg
    fi
    menu_add output "Output" device-speaker.svg "$(nodes sinks | nick_of "$(pactl get-default-sink)")"
    menu_add input "Input" microphone.svg "$(nodes sources | nick_of "$(pactl get-default-source)")"
    ((stream_count > 0)) && menu_add apps "App Volume" apps.svg "$stream_count playing"

    menu_show audio "$mesg" "$selected" || break
    selected="$MENU_ID"
    case "$MENU_ID" in
        up) menu_run wpctl set-volume --limit 1.0 $sink 5%+ ;;
        down) menu_run wpctl set-volume $sink 5%- ;;
        mute) menu_run wpctl set-mute $sink toggle ;;
        mic) menu_run wpctl set-mute $src toggle ;;
        output) device_menu sinks ;;
        input) device_menu sources ;;
        apps) apps_menu ;;
    esac
done
