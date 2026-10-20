#!/bin/bash
# Keybind cheat sheet built from the "-- kb:" tags in keybinds.lua, plus
# fuzzel's own menu keys, which aren't Hyprland binds. Entries with a
# "-- run:" line (marked ▸) run that command on Enter.

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

SEP=$'\x1f'
RUN=()

menu_reset
i=0
while IFS="$SEP" read -r combo desc cmd; do
    RUN[i]="$cmd"
    marker="  "
    [ -n "$cmd" ] && marker="▸ "
    menu_add "kb$i" "$marker$desc" "" "$(pretty_combo "$combo")"
    i=$((i + 1))
done < <(awk -v sep="$SEP" '
    function emit(   n) {
        n = index(k, " | ")
        print substr(k, 1, n - 1) sep substr(k, n + 3) sep run
        pend = 0
    }
    /^-- kb: / { if (pend) emit(); k = substr($0, 8); run = ""; pend = 1; next }
    /^-- run: / { if (pend) run = substr($0, 9); next }
    { if (pend) emit() }
    END { if (pend) emit() }
' "$kb_file")

menu_add menu-nav "Menus: next / previous entry" "" "Ctrl + J / Ctrl + K"
menu_add menu-cursor "Menus: cursor left / right" "" "Ctrl + H / Ctrl + L"
menu_add menu-page "Menus: next / previous page" "" "Ctrl + D / Ctrl + U"
menu_add menu-back "Menus: go back one level" "" "Escape"

MENU_PLACEHOLDER="Search keybinds"
selected=""
while menu_show keybinds "▸ = Enter runs it" "$selected"; do
    selected="$MENU_ID"
    [[ "$MENU_ID" == kb* ]] || continue
    cmd="${RUN[${MENU_ID#kb}]}"
    [ -n "$cmd" ] || continue
    # Run after the menu closes so slurp, screenshots and focus see the desktop.
    (sleep 0.3; exec setsid bash -c "$cmd" >/dev/null 2>&1) &
    menu_done
done
