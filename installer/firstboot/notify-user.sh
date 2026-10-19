#!/usr/bin/env bash
# Sourced, not run. Best-effort desktop notification to the logged-in user
# from a root script; a no-op if no session is active. Caller must set GLYPH.
# Prints the notification id so callers can pass it back as replace_id.
# The optional 5th arg is a 0-100 progress value.
notify_user() {
    local urgency="$1" title="$2" body="$3" replace_id="${4:-0}" percent="${5:-}"
    command -v notify-send >/dev/null 2>&1 || { echo 0; return 0; }
    local session_user
    session_user="$(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $3; exit}')"
    [[ -n "$session_user" ]] || { echo 0; return 0; }
    local uid
    uid="$(id -u "$session_user" 2>/dev/null)" || { echo 0; return 0; }
    local hint_args=()
    [[ -n "$percent" ]] && hint_args=(--hint="int:value:$percent")
    runuser -u "$session_user" -- env XDG_RUNTIME_DIR="/run/user/$uid" \
        notify-send -p -r "$replace_id" -u "$urgency" "${hint_args[@]}" "$GLYPH  $title" "$body" 2>/dev/null || echo 0
}
