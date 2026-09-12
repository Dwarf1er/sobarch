#!/bin/bash

vol_raw=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
volpct=$(echo "$vol_raw" | awk '{printf "%d", $2*100}')
if echo "$vol_raw" | grep -q MUTED; then
    icon="󰝟"
else
    icon="󰕾"
fi

printf '{"text": "%s %s%%", "tooltip": "Volume: %s%%"}\n' "$icon" "$volpct" "$volpct"
