#!/usr/bin/env bash
# Lists every file in ~/.local/share/backgrounds/ (the standard user
# wallpaper directory: it's the per-user counterpart of the
# system-wide /usr/share/backgrounds most distros ship their own
# default wallpapers under, both under the freedesktop.org "backgrounds"
# convention GNOME's own wallpaper picker already uses -- there is no
# XDG Base Directory Specification entry for wallpapers specifically,
# this is the closest thing to a standard). Both tinty-compatible SVGs
# (see apply-wallpaper.sh's own comment for the id="sobarch-bg"/
# id="sobarch-accent" contract) and plain images are listed the same
# way; apply-wallpaper.sh is the one that tells them apart.
#
# Stays open after applying one, cursor kept on it and marked current,
# so browsing through several to compare is Enter, Down, Enter... rather
# than reopening the picker each time.

source "$HOME/.config/hypr/scripts/menu-lib.sh"

MENU_TITLE="sobarch: wallpaper"
MENU_ICON="photo.svg"
BACKGROUNDS_DIR="$HOME/.local/share/backgrounds"
CURRENT_FILE="$HOME/.config/sobarch/current-wallpaper"

# Each row's icon is the wallpaper file itself (a real image, not an
# icon-theme name), so fuzzel renders an actual thumbnail; row height is
# raised well past the default since a thumbnail is unrecognizable at
# normal height.
MENU_LINE_HEIGHT=40
MENU_PLACEHOLDER="Search wallpapers"

shopt -s nullglob
files=("$BACKGROUNDS_DIR"/*)
shopt -u nullglob

if ((${#files[@]} == 0)); then
    menu_notify "No files in $BACKGROUNDS_DIR to pick from." critical
    exit 1
fi

# "sobarch_wallpaper-2.png" -> "Sobarch Wallpaper 2".
pretty() {
    local name="${1##*/}" out="" word
    name="${name%.*}"
    for word in ${name//[-_]/ }; do
        out+="${out:+ }${word^}"
    done
    printf '%s' "$out"
}

mapfile -t files < <(printf '%s\n' "${files[@]}" | sort -f)

selected=""
while :; do
    current=$(cat "$CURRENT_FILE" 2>/dev/null)
    [ -n "$selected" ] || selected="$current"
    menu_reset
    for f in "${files[@]}"; do
        menu_add "$f" "$(pretty "$f")" "$f,image-x-generic" "$([ "$f" = "$current" ] && echo current)"
    done
    menu_show wallpaper "" "$selected" || break
    selected="$MENU_ID"
    mkdir -p "$(dirname "$CURRENT_FILE")"
    printf '%s' "$MENU_ID" >"$CURRENT_FILE"
    "$HOME/.config/hypr/scripts/apply-wallpaper.sh" ||
        menu_notify "Failed to apply $(pretty "$MENU_ID")." critical
done
