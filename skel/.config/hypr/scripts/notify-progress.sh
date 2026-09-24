#!/bin/bash
# Sourced by menu scripts that wrap a long-running action, never run
# directly: notify-send's default expiry timeout hides a "started"
# toast long before a device scan or an aur-sync rebuild that can run
# for minutes actually finishes, leaving no visible sign anything is
# still happening. notify_progress prints the notification's id (via
# -p), same convention installer/firstboot/notify-user.sh's
# notify_user() uses, so a caller can pass it back in as replace_id to
# turn a persistent "in progress" toast into its own final result
# instead of stacking a second one next to a toast that's already gone.
#
# Deliberately not notify-user.sh's notify_user() itself: that helper
# reaches into the logged-in user's session from a root process with no
# session of its own (apply-security-baseline.sh,
# install-profile-packages.sh). These menu scripts already run in the
# user's own session, calling notify-send directly like every other
# menu script here already does, so none of that is needed.
#
# Usage: id=$(notify_progress URGENCY TITLE BODY [REPLACE_ID] [PERSIST])
# PERSIST (any non-empty value) sets no expiry timeout, for the
# "in progress" call; omit it on the follow-up call that replaces it,
# so the final result uses the normal auto-expiring timeout.
notify_progress() {
    local urgency="$1" title="$2" body="$3" replace_id="${4:-0}" persist="${5:-}"
    local ttl_args=()
    [ -n "$persist" ] && ttl_args=(-t 0)
    notify-send -p -r "$replace_id" -u "$urgency" "${ttl_args[@]}" "$title" "$body"
}
