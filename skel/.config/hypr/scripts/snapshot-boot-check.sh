#!/usr/bin/env bash
# Run at login. On a Limine snapshot boot (FSROOT /@snapshots/N/snapshot),
# shows a persistent notification offering to make that snapshot permanent.
# mako keeps critical notifications until dismissed.

set -uo pipefail

source "$HOME/.config/hypr/scripts/confirm.sh"
source "$HOME/.config/hypr/scripts/notify-progress.sh"

ICONS="$HOME/.config/sobarch/icons"
TITLE="sobarch: running a snapshot"

fsroot="$(findmnt -no FSROOT / 2>/dev/null)"
[[ "$fsroot" =~ ^/@snapshots/([0-9]+)/snapshot$ ]] || exit 0
num="${BASH_REMATCH[1]}"

action="$(notify-send --wait -u critical -A "default=Make permanent" -i "$ICONS/refresh.svg" "$TITLE" \
    "You booted snapshot $num. Changes you make here are lost on the next normal boot. Click to make it your permanent system.")"
[[ "$action" == default ]] || exit 0

confirm "Make snapshot $num permanent? This session's changes are discarded." "Make Permanent" || exit 0

id=$(notify_progress normal "$TITLE" "Restoring snapshot $num as the new root..." 0 persist)
if sobarch snapshot-restore --yes "$num"; then
    notify_progress normal "$TITLE" "Snapshot $num restored. Reboot to use it." "$id" >/dev/null
    confirm "Restart now to finish?" "Restart" && systemctl reboot
else
    notify_progress critical "$TITLE" "Restore failed or was cancelled; nothing was changed." "$id" >/dev/null
fi
