#!/usr/bin/env bash
# Run once per Hyprland login (hyprland.lua's autostart). If this boot
# is a Limine snapshot entry (sobarch-limine-snapshot-sync's
# `rootflags=...,subvol=/@snapshots/N/snapshot`), shows a persistent
# notification saying so; clicking it offers to make that snapshot the
# permanent root via snapshot-rollback.sh --online, the same restore a
# terminal user would run by hand.
#
# Detection: `findmnt -no FSROOT /` is the subvolume path / is mounted
# from. A normal boot reports "/@"; a snapshot boot reports
# "/@snapshots/N/snapshot". A no-op (exits immediately) on anything
# else, including non-BTRFS roots.
#
# Critical urgency is what makes the notification persistent: mako's
# own config (skel/.config/mako/config) sets default-timeout=0 for
# [urgency=critical], so it stays until clicked or dismissed.

set -uo pipefail

source "$HOME/.config/hypr/scripts/confirm.sh"
source "$HOME/.config/hypr/scripts/notify-progress.sh"

ROLLBACK="/usr/local/lib/sobarch/snapshot-rollback.sh"
ICONS="$HOME/.config/sobarch/icons"
TITLE="sobarch: running a snapshot"

fsroot="$(findmnt -no FSROOT / 2>/dev/null)"
[[ "$fsroot" =~ ^/@snapshots/([0-9]+)/snapshot$ ]] || exit 0
num="${BASH_REMATCH[1]}"

action="$(notify-send --wait -u critical -A "default=Make permanent" -i "$ICONS/refresh.svg" "$TITLE" \
    "You booted snapshot $num. Changes you make here are lost on the next normal boot. Click to make it your permanent system.")"
[[ "$action" == default ]] || exit 0

confirm "Make snapshot $num permanent? (this session's changes are discarded)" || exit 0

id=$(notify_progress normal "$TITLE" "Restoring snapshot $num as the new root..." 0 persist)
if pkexec "$ROLLBACK" --online --yes "$num"; then
    notify_progress normal "$TITLE" "Snapshot $num restored. Reboot to use it." "$id" >/dev/null
    confirm "Reboot now?" && systemctl reboot
else
    notify_progress critical "$TITLE" "Restore failed or was cancelled; nothing was changed." "$id" >/dev/null
fi
