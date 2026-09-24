#!/bin/bash
# Cheat sheet: greps keybinds.lua for "-- kb: <combo> | <description>"
# tags, one per real hl.bind() call, so this list can't drift far from
# the actual binds. A short manual tail covers fuzzel's own vim-style
# additions (fuzzel.ini's [key-bindings] section), since those aren't
# Hyprland binds at all and have no hl.bind() call to tag.
#
# A plain pager (same `kitty -e less` convention update-config-menu.sh's
# own diff view already uses), not a fuzzel dmenu list: this is a
# read-only reference sheet, and a searchable picker whose own comment
# admitted selecting a row does nothing was the wrong widget for that.
# less's own "/" search replaces fuzzel's filter-as-you-type for free.

kb_file="$HOME/.config/hypr/keybinds.lua"

tmp="$(mktemp)"
{
    grep -oP '(?<=-- kb: ).*' "$kb_file" | awk -F' *\\| *' '{printf "%-26s %s\n", $1, $2}'

    printf "%-26s %s\n" "Ctrl+J / Ctrl+K" "fuzzel: next / previous entry"
    printf "%-26s %s\n" "Ctrl+H / Ctrl+L" "fuzzel: cursor left / right"
    printf "%-26s %s\n" "Ctrl+D / Ctrl+U" "fuzzel: next / previous page"
} > "$tmp"
kitty -e less "$tmp"
rm -f "$tmp"
