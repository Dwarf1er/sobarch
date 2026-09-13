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
set -euo pipefail

TITLE=$'\U000F0E09'"  sobarch: wallpaper"
BACKGROUNDS_DIR="$HOME/.local/share/backgrounds"
CURRENT_FILE="$HOME/.config/sobarch/current-wallpaper"

shopt -s nullglob
files=("$BACKGROUNDS_DIR"/*)
shopt -u nullglob

if [[ ${#files[@]} -eq 0 ]]; then
    notify-send -u critical "$TITLE" "No files in $BACKGROUNDS_DIR to pick from."
    exit 1
fi

# Pretty name (extension stripped, dashes/underscores turned into
# spaces) shown in the picker, tab-separated from the real path
# (hidden via --with-nth) for the actual selection.
choice=$(for f in "${files[@]}"; do
    name="$(basename "$f")"
    name="${name%.*}"
    name="${name//[-_]/ }"
    printf "%s\t%s\n" "$name" "$f"
done | sort -f | fuzzel --dmenu --with-nth=1 --prompt "wallpaper: ")
[[ -n "${choice:-}" ]] || exit 0

pretty="${choice%%$'\t'*}"
path="${choice#*$'\t'}"

mkdir -p "$(dirname "$CURRENT_FILE")"
printf "%s" "$path" >"$CURRENT_FILE"

if "$HOME/.config/hypr/scripts/apply-wallpaper.sh"; then
    notify-send "$TITLE" "Applied $pretty."
else
    notify-send -u critical "$TITLE" "Failed to apply $pretty."
fi
