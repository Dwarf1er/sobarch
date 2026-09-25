#!/bin/bash
# Cheat sheet: greps keybinds.lua for "-- kb: <combo> | <description>"
# tags, one per real hl.bind() call, so this list can't drift far from
# the actual binds. A short manual tail covers fuzzel's own vim-style
# additions (fuzzel.ini's [key-bindings] section), since those aren't
# Hyprland binds at all and have no hl.bind() call to tag.
# Read-only: this just displays the list, selecting an entry does nothing.
#
# Fuzzel has no markup/rich-text support, so key names are bracketed
# ("[SUPER]+[T]") to approximate markdown's <kbd> styling in plain text.

kb_file="$HOME/.config/hypr/keybinds.lua"

kbd() {
    local combo="$1" part
    local -a out=()
    local IFS='+'
    for part in $combo; do
        part="${part#"${part%%[![:space:]]*}"}"
        part="${part%"${part##*[![:space:]]}"}"
        out+=("[$part]")
    done
    local IFS='+'
    printf '%s' "${out[*]}"
}

{
    while IFS='|' read -r combo desc; do
        combo="${combo%"${combo##*[![:space:]]}"}"
        desc="${desc#"${desc%%[![:space:]]*}"}"
        printf "%-28s %s\n" "$(kbd "$combo")" "$desc"
    done < <(grep -oP '(?<=-- kb: ).*' "$kb_file")

    printf "%-28s %s\n" "$(kbd "Ctrl+J") / $(kbd "Ctrl+K")" "fuzzel: next / previous entry"
    printf "%-28s %s\n" "$(kbd "Ctrl+H") / $(kbd "Ctrl+L")" "fuzzel: cursor left / right"
    printf "%-28s %s\n" "$(kbd "Ctrl+D") / $(kbd "Ctrl+U")" "fuzzel: next / previous page"
} | fuzzel --dmenu --prompt "keybinds: " --lines 15 --width 57 >/dev/null
