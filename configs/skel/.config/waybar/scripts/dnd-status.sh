#!/bin/bash

if makoctl mode 2>/dev/null | grep -qx "do-not-disturb"; then
    printf '{"text": "󰎢", "tooltip": "Do Not Disturb: on", "class": "active"}\n'
else
    printf '{"text": "", "tooltip": "Do Not Disturb: off", "class": "inactive"}\n'
fi
