#!/usr/bin/env bash
# Sourced by apply-security-baseline.sh and install-profile-packages.sh,
# never run directly: best-effort desktop notification into the
# logged-in user's session for a script that runs as root with no
# controlling terminal, where a failure is otherwise invisible until
# someone thinks to check journalctl. A no-op if no graphical session
# is active yet (e.g. a network blip right after boot before anyone's
# logged in) or notify-send isn't installed.
#
# Expects the caller to set GLYPH (a Nerd Fonts Material Design Icons
# codepoint, prefixed on every notification title) before sourcing this.
#
# notify_user prints the notification's id (via -p) so a caller can
# pass it back in as replace_id to update that same notification in
# place, rather than piling up a new transient one per step. An
# optional 5th arg renders a real progress bar (mako/dunst both support
# the standard int:value:NN hint, 0-100) instead of leaving "how far
# along is this" to the body text alone.
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
