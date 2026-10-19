#!/bin/bash
# Sobarch settings menu; rows show current state.

source "$HOME/.config/hypr/scripts/menu-lib.sh"

SKEL_SRC="/usr/share/sobarch/skel"

# apply-skel.sh only writes .sobarch-new next to shipped skel paths.
conflict_count() {
    local rel n=0
    [ -d "$SKEL_SRC" ] || return
    while IFS= read -r rel; do
        [ -e "$HOME/$rel.sobarch-new" ] && n=$((n + 1))
    done < <(find "$SKEL_SRC" -type f -printf '%P\n')
    ((n > 0)) && echo "$n pending"
}

# "base16-gruvbox-dark-hard" -> "Gruvbox Dark Hard"
current_theme() {
    command -v tinty >/dev/null || return
    tinty current 2>/dev/null | awk -F- '{
        out = ""
        for (i = 2; i <= NF; i++) out = out (out ? " " : "") toupper(substr($i, 1, 1)) substr($i, 2)
        print out
    }'
}

current_wallpaper() {
    local f out="" word
    f=$(cat "$HOME/.config/sobarch/current-wallpaper" 2>/dev/null) || return
    f="${f##*/}"
    f="${f%.*}"
    for word in ${f//[-_]/ }; do
        out+="${out:+ }${word^}"
    done
    echo "$out"
}

# rescue-iso-setup.sh labels the rescue partition RESCUE.
has_rescue=0
lsblk -rno LABEL 2>/dev/null | grep -qx RESCUE && has_rescue=1

selected=""
while :; do
    menu_reset
    menu_add update "Update System" refresh.svg
    menu_add conflicts "Review Conflicts" git-merge.svg "$(conflict_count)"
    menu_add install "Install Apps" download.svg
    menu_add themes "Theme" palette.svg "$(current_theme)"
    menu_add wallpaper "Wallpaper" photo.svg "$(current_wallpaper)"
    menu_add mimetypes "Default Apps" apps.svg
    ((has_rescue)) && menu_add rescue "Refresh Rescue ISO" device-usb.svg
    menu_add docs "Documentation" book.svg

    menu_show "sobarch settings" "" "$selected" || break
    selected="$MENU_ID"
    case "$MENU_ID" in
        # Long-running flow with its own UI; nothing to return to.
        update) sobarch update --gui; menu_done ;;
        conflicts) sobarch review-conflicts --gui ;;
        install) menu_sub setup-package-menu.sh ;;
        themes) menu_sub themes-menu.sh ;;
        wallpaper) menu_sub wallpaper-menu.sh ;;
        mimetypes) menu_sub mimetype-menu.sh ;;
        rescue) menu_sub refresh-rescue-menu.sh ;;
        docs) xdg-open "https://sobarch.antoinepoulin.com" & menu_done ;;
    esac
done
