#!/bin/bash
# Lid handling for laptops, called from hyprland.lua.
#
#   lid.sh close   disable the built-in panel if an external monitor is active
#   lid.sh open    bring the built-in panel back
#   lid.sh sync    hold or drop the lid inhibitor to match the connected monitors
#   lid.sh restore after resume, re-enable the built-in panel if no external is active
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

internal_lit() { cat /sys/class/drm/card*-{eDP,LVDS,DSI}-*/enabled 2>/dev/null | grep -q '^enabled'; }

# The kernel can reject the first modeset right after a dock is unplugged, yet
# Hyprland still records the panel as enabled and a plain reload is then a no-op.
# So check the kernel's view, and force a disable/enable cycle until it sticks.
revive_panel() {
    local i m
    (
        flock -w 30 9
        for i in 1 2 3; do
            internal_lit && exit 0
            for m in $(internal_monitors); do
                hyprctl eval "hl.monitor({ output = \"$m\", disabled = true })" >/dev/null
            done
            sleep 1
            hyprctl reload >/dev/null
            sleep 2
        done
    ) 9>"${XDG_RUNTIME_DIR:-/tmp}/sobarch-lid-revive.lock"
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
        external_active || revive_panel
        ;;
    restore)
        # After resume the lid-open event can be missing (T2 Macs), so bring the
        # built-in panel back whenever no external monitor is left to show things.
        external_active || { revive_panel; hyprctl dispatch 'hl.dsp.dpms({ action = "on" })'; }
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
                revive_panel
            fi
            # With the lid still shut there is nothing left to show; the panel is
            # restored on resume (hypridle) or when the lid opens.
            lid_closed && systemctl suspend
        fi
        ;;
    *)
        echo "usage: ${0##*/} close|open|sync|restore" >&2
        exit 2
        ;;
esac
