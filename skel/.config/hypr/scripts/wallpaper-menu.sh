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
# (hidden via --with-nth) for the actual selection. The \0icon\x1f
# suffix is fuzzel's own extended dmenu protocol (rofi's), and is
# stripped before the tab-separated text is ever returned on stdin --
# confirmed directly, it doesn't leak into $choice below. Pointing it
# at the wallpaper's own file (real image, not an icon-theme name)
# renders an actual thumbnail; --line-height is bumped well past
# fuzzel's default for this menu specifically (other menus stay at the
# default) since the thumbnail is unrecognizable at normal row height.
# --minimal-lines (sizes the window to min(lines, actual entry count)
# instead of always reserving fuzzel.ini's full lines=8) isn't just a
# sizing nicety here: confirmed directly, an SVG icon (unlike a PNG)
# left in the *unused* leftover row space below a short entry list
# renders a second, oversized, mispositioned copy of itself -- a real
# fuzzel rendering bug, reproduced with a single-SVG-entry list
# matching this menu's actual real-world case, gone entirely once no
# empty leftover rows exist to trigger it.
choice=$(for f in "${files[@]}"; do
    name="$(basename "$f")"
    name="${name%.*}"
    name="${name//[-_]/ }"
    printf "%s\t%s\0icon\x1f%s,image-x-generic\n" "$name" "$f" "$f"
done | sort -f | fuzzel --dmenu --with-nth=1 --line-height=40 --minimal-lines --prompt "wallpaper: ")
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
