#!/bin/bash
# Keybind cheat sheet built from the "-- kb:" tags in keybinds.lua, plus
# fuzzel's own menu keys, which aren't Hyprland binds.

source "$HOME/.config/hypr/scripts/menu-lib.sh"

kb_file="$HOME/.config/hypr/keybinds.lua"

# "SUPER + SHIFT + T" -> "Super + Shift + T"; single letters, digits and
# already-mixed-case names ("Print Screen") pass through untouched.
pretty_combo() {
    awk -F' [+] ' '{
        out = ""
        for (i = 1; i <= NF; i++) {
            k = $i
            if (k ~ /^[A-Z]+$/ && length(k) > 1) k = substr(k, 1, 1) tolower(substr(k, 2))
            out = out (i > 1 ? " + " : "") k
        }
        print out
    }' <<<"$1"
}

menu_reset
i=0
while IFS='|' read -r combo desc; do
    combo="${combo%"${combo##*[![:space:]]}"}"
    desc="${desc#"${desc%%[![:space:]]*}"}"
    menu_add "kb$((i++))" "$desc" "" "$(pretty_combo "$combo")"
done < <(grep -oP '(?<=-- kb: ).*' "$kb_file")

menu_add menu-nav "Menus: next / previous entry" "" "Ctrl + J / Ctrl + K"
menu_add menu-cursor "Menus: cursor left / right" "" "Ctrl + H / Ctrl + L"
menu_add menu-page "Menus: next / previous page" "" "Ctrl + D / Ctrl + U"
menu_add menu-back "Menus: go back one level" "" "Escape"

MENU_PLACEHOLDER="Search keybinds"
selected=""
while menu_show keybinds "" "$selected"; do
    selected="$MENU_ID"
done
