#!/usr/bin/env bash
# Wallpaper picker over ~/.local/share/backgrounds/. apply-wallpaper.sh
# handles recolorable SVGs and plain images. Stays open after applying.

source "$HOME/.config/hypr/scripts/menu-lib.sh"

MENU_TITLE="sobarch: wallpaper"
MENU_ICON="photo.svg"
BACKGROUNDS_DIR="$HOME/.local/share/backgrounds"
CURRENT_FILE="$HOME/.config/sobarch/current-wallpaper"

# Icons are the wallpaper files themselves, so rows are tall enough for thumbnails.
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
