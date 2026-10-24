#!/bin/bash
# Lid handling for laptops, called from hyprland.lua.
#
#   lid.sh close   disable the built-in panel if an external monitor is active
#   lid.sh open    bring the built-in panel back
#   lid.sh sync    hold or drop the lid inhibitor to match the connected monitors
#
# While an external monitor is active, systemd-logind is told to ignore the lid
# so the machine keeps running; with none, logind suspends as usual.

INHIBIT_PID="${XDG_RUNTIME_DIR:-/tmp}/sobarch-lid-inhibit.pid"

internal_monitors() { hyprctl monitors all | awk '/^Monitor / && $2 ~ /^(eDP|LVDS|DSI)/ { print $2 }'; }

external_active() {
    hyprctl monitors | awk '/^Monitor / && $2 !~ /^(eDP|LVDS|DSI)/ { found = 1 } END { exit !found }'
}

disabled_internal_monitors() {
    hyprctl monitors all | awk '
        /^Monitor / { name = $2; next }
        /^\tdisabled: true/ && name ~ /^(eDP|LVDS|DSI)/ { print name }'
}

lid_closed() { grep -qs closed /proc/acpi/button/lid/*/state; }

inhibit() {
    [ -f "$INHIBIT_PID" ] && kill -0 "$(cat "$INHIBIT_PID")" 2>/dev/null && return
    systemd-inhibit --what=handle-lid-switch --who=sobarch --why="External monitor connected" \
        sleep infinity >/dev/null 2>&1 &
    echo $! >"$INHIBIT_PID"
}

release() {
    [ -f "$INHIBIT_PID" ] && kill "$(cat "$INHIBIT_PID")" 2>/dev/null
    rm -f "$INHIBIT_PID"
}

case "${1:-}" in
    close)
        external_active || exit 0
        for m in $(internal_monitors); do
            hyprctl eval "hl.monitor({ output = \"$m\", disabled = true })" >/dev/null
        done
        ;;
    open)
        hyprctl reload >/dev/null
        ;;
    sync)
        if external_active; then
            inhibit
        else
            release
            # A saved "disabled" rule must not leave the machine with no display.
            if ! lid_closed; then
                for m in $(disabled_internal_monitors); do
                    hyprctl eval "hl.monitor({ output = \"$m\", mode = \"preferred\", position = \"auto\", scale = \"auto\" })" >/dev/null
                done
            fi
            # Last external monitor unplugged with the lid shut: nothing left to show.
            lid_closed && systemctl suspend
        fi
        ;;
    *)
        echo "usage: ${0##*/} close|open|sync" >&2
        exit 2
        ;;
esac
