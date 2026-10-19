#!/bin/bash
# The icon comes from style.css, keyed off "class". Rounds like system-menu.sh.

vol_raw=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null) || {
    printf '{"text": ""}\n'
    exit 0
}
volpct=$(awk '{printf "%d", $2 * 100 + 0.5}' <<<"$vol_raw")
if [[ "$vol_raw" == *MUTED* ]]; then
    printf '{"text": "%s%%", "tooltip": "Volume: muted", "class": "muted"}\n' "$volpct"
else
    printf '{"text": "%s%%", "tooltip": "Volume: %s%%", "class": "unmuted"}\n' "$volpct" "$volpct"
fi
