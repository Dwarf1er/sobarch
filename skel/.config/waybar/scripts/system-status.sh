#!/bin/bash
# The icon itself comes from style.css's background-image, keyed off
# "class" below (see waybar-css's tinty template); "text" only carries
# the volume percentage now, no glyph concatenated into it.

vol_raw=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
volpct=$(echo "$vol_raw" | awk '{printf "%d", $2*100}')
if echo "$vol_raw" | grep -q MUTED; then
    class="muted"
else
    class="unmuted"
fi

printf '{"text": "%s%%", "tooltip": "Volume: %s%%", "class": "%s"}\n' "$volpct" "$volpct" "$class"
