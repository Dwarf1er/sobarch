#!/bin/bash
# Start or stop a screen recording; the recording itself is record.sh.

source "$HOME/.config/hypr/scripts/menu-lib.sh"

MENU_TITLE="sobarch: recording"
MENU_ICON="movie.svg"

menu_reset
if pgrep -x wf-recorder >/dev/null; then
    menu_add stop "Stop Recording" x.svg
else
    menu_add region "Record Region" movie.svg
    menu_add screen "Record Screen" movie.svg
fi
menu_show recording || exit 0
# A recording starts after the menu closes so slurp gets the screen.
"$MENU_SCRIPTS/record.sh" "$MENU_ID" &
menu_done
