#!/bin/bash
# Screen recording with wf-recorder, no audio.
#
#   record.sh region|screen|stop|toggle     toggle: stop if recording, else region

source "$HOME/.config/hypr/scripts/notify-progress.sh"

ICON="$HOME/.config/sobarch/icons/movie.svg"
STATE="${XDG_RUNTIME_DIR:-/tmp}/sobarch-recording"
OUT_DIR="$(xdg-user-dir VIDEOS 2>/dev/null || echo "$HOME/Videos")"

recording() { pgrep -x wf-recorder >/dev/null; }

stop() {
    local file id
    recording || return 0
    pkill -INT -x wf-recorder
    while recording; do sleep 0.1; done
    { read -r file; read -r id; } <"$STATE" 2>/dev/null
    rm -f "$STATE"
    notify_progress normal "Recording saved" "${file/#$HOME/\~}" "${id:-0}" "" "$ICON" >/dev/null
}

start() {
    local args=() file id
    case "$1" in
        region)
            local geometry
            geometry=$(slurp) || exit 0
            args=(-g "$geometry")
            ;;
        screen)
            args=(-o "$(hyprctl monitors | awk '/^Monitor/{name=$2} /focused: yes/{print name; exit}')")
            ;;
    esac
    mkdir -p "$OUT_DIR"
    file="$OUT_DIR/recording-$(date +%Y%m%d-%H%M%S).mp4"
    id=$(notify_progress normal "Recording" "Press Super+Shift+R to stop." 0 persist "$ICON")
    printf '%s\n%s\n' "$file" "$id" >"$STATE"
    setsid wf-recorder "${args[@]}" -f "$file" >/dev/null 2>&1 &
}

case "${1:-toggle}" in
    stop) stop ;;
    region | screen | toggle)
        if recording; then stop; else start "${1/toggle/region}"; fi
        ;;
    *)
        echo "record.sh: unknown action '${1:-}'" >&2
        exit 2
        ;;
esac
