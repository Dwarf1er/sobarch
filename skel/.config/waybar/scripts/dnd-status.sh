#!/bin/bash
# The icon itself comes from style.css's background-image on
# #custom-dnd.active (see waybar-css's tinty template); this only
# needs to report which state applies. "inactive" carries no icon at
# all -- #custom-dnd collapses to zero width when inactive, same as
# before.

if makoctl mode 2>/dev/null | grep -qx "do-not-disturb"; then
    printf '{"text": " ", "tooltip": "Do Not Disturb: on", "class": "active"}\n'
else
    printf '{"text": "", "tooltip": "Do Not Disturb: off", "class": "inactive"}\n'
fi
