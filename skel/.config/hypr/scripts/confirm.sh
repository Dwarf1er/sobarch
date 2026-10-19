#!/bin/bash
# Sourced by menu scripts that gate a destructive action, never run
# directly: a shared confirmation step using the same fuzzel picker
# every other menu already uses. Cancel is listed first since fuzzel
# highlights the first entry by default, so a stray Enter never confirms
# a destructive action by accident. The question renders as the message
# above the prompt rather than as the prompt itself, so a long one
# ("Overwrite .bashrc with the new version?") wraps instead of pushing
# the input off the edge, and the confirming row names the action
# ("Remove", "Shut Down") rather than a bare "Yes", the way a native
# dialog's button would. Line height 28, the same cap menu-lib.sh uses
# under a multi-line message (fuzzel spaces message lines by it too),
# without depending on it: update-system.sh sources this alone.
#
# Usage: confirm QUESTION [VERB]   (VERB defaults to "Yes")

confirm() {
    local icons="$HOME/.config/sobarch/icons"
    [ "$(printf '%s\0icon\x1f%s\n' "Cancel" "$icons/x.svg" "${2:-Yes}" "$icons/check.svg" \
        | fuzzel --dmenu --index --only-match --minimal-lines --lines 2 --line-height 28 \
            --width 40 --mesg "${1:-Are you sure?}" --prompt "confirm  " --placeholder "")" = 1 ]
}
