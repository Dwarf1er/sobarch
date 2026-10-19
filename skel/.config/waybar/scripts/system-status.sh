#!/bin/bash
# The icon comes from style.css, keyed off "class".

vol_raw=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
volpct=$(echo "$vol_raw" | awk '{printf "%d", $2*100}')
if echo "$vol_raw" | grep -q MUTED; then
    class="muted"
else
    class="unmuted"
fi

printf '{"text": "%s%%", "tooltip": "Volume: %s%%", "class": "%s"}\n' "$volpct" "$volpct" "$class"
