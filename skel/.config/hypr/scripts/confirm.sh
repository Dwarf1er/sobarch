#!/bin/bash
# Sourced, not run. confirm QUESTION [VERB]: VERB defaults to "Yes".
# Cancel is listed first so a stray Enter never confirms.
# Kept independent of menu-lib.sh because update-system.sh sources this alone.

confirm() {
    local icons="$HOME/.config/sobarch/icons"
    [ "$(printf '%s\0icon\x1f%s\n' "Cancel" "$icons/x.svg" "${2:-Yes}" "$icons/check.svg" \
        | fuzzel --dmenu --index --only-match --minimal-lines --lines 2 --line-height 28 \
            --width 40 --mesg "${1:-Are you sure?}" --prompt "confirm  " --placeholder "")" = 1 ]
}
