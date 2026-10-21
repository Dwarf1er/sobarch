#!/bin/bash
# Update channel: stable follows master, develop is the unsupported nightly branch.

source "$HOME/.config/hypr/scripts/menu-lib.sh"

MENU_TITLE="sobarch: update channel"
MENU_ICON="refresh.svg"

current=$(sobarch channel 2>/dev/null)
menu_reset
menu_add stable "Stable" lock.svg "$([ "$current" = stable ] && echo active)"
menu_add develop "Develop (nightly)" git-merge.svg "$([ "$current" = develop ] && echo active)"
menu_show "update channel" "" "$current" || exit 0
[ "$MENU_ID" = "$current" ] && exit 0

if [ "$MENU_ID" = develop ]; then
    confirm "Develop is the unsupported nightly branch and can break. Switch anyway?" Switch || exit 0
else
    confirm "Switching back does not downgrade packages already updated from develop; they may be newer than stable expects. Restore a snapshot to undo them. Switch anyway?" Switch || exit 0
fi

if out=$(sobarch channel --yes "$MENU_ID" 2>&1); then
    menu_notify "Update channel set to $MENU_ID."
else
    menu_notify "${out:-Could not change the channel.}" critical
fi
menu_done
