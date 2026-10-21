#!/bin/bash
# Empty (so the chip collapses) unless the default mic is muted.

if wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | grep -q MUTED; then
    printf '{"text": " ", "tooltip": "Microphone: muted", "class": "muted"}\n'
else
    printf '{"text": "", "tooltip": "Microphone: on", "class": "unmuted"}\n'
fi
