#!/bin/bash
# Cheat sheet: greps keybinds.lua for "-- kb: <combo> | <description>"
# tags, one per real hl.bind() call, so this list can't drift far from
# the actual binds. A short manual tail covers fuzzel's own vim-style
# additions (fuzzel.ini's [key-bindings] section), since those aren't
# Hyprland binds at all and have no hl.bind() call to tag.
# Read-only: this just displays the list, selecting an entry does nothing.

kb_file="$HOME/.config/hypr/keybinds.lua"

{
    grep -oP '(?<=-- kb: ).*' "$kb_file" | awk -F' *\\| *' '{printf "%-26s %s\n", $1, $2}'

    printf "%-26s %s\n" "Ctrl+J / Ctrl+K" "fuzzel: next / previous entry"
    printf "%-26s %s\n" "Ctrl+H / Ctrl+L" "fuzzel: cursor left / right"
    printf "%-26s %s\n" "Ctrl+D / Ctrl+U" "fuzzel: next / previous page"
} | fuzzel --dmenu --prompt "keybinds: " --lines 15 --width 55 >/dev/null
