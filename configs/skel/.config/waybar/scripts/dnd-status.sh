#!/bin/bash
# Shows a bell-off icon when mako's do-not-disturb mode is active, nothing otherwise.

if makoctl mode 2>/dev/null | grep -qx "do-not-disturb"; then
    printf '{"text": "󰎢", "tooltip": "Do Not Disturb: on", "class": "active"}\n'
else
    printf '{"text": "", "tooltip": "Do Not Disturb: off", "class": "inactive"}\n'
fi
