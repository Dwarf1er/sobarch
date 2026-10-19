#!/bin/bash
# Sourced, not run. Prints the notification id so a persistent "in
# progress" toast can be replaced by its result.
#
# Usage: id=$(notify_progress URGENCY TITLE BODY [REPLACE_ID] [PERSIST] [ICON])
# PERSIST (any non-empty value) disables the expiry timeout.
notify_progress() {
    local urgency="$1" title="$2" body="$3" replace_id="${4:-0}" persist="${5:-}" icon="${6:-}"
    local ttl_args=()
    [ -n "$persist" ] && ttl_args=(-t 0)
    local icon_args=()
    [ -n "$icon" ] && icon_args=(-i "$icon")
    notify-send -p -r "$replace_id" -u "$urgency" "${ttl_args[@]}" "${icon_args[@]}" "$title" "$body"
}
