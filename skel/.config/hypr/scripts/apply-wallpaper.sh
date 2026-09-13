#!/usr/bin/env bash
# Applies whatever wallpaper is currently selected (~/.config/sobarch/
# current-wallpaper, a plain text file holding one absolute path,
# written by wallpaper-menu.sh; defaults to sobarch's own shipped
# ~/.local/share/backgrounds/sobarch-wallpaper.svg if that file doesn't
# exist yet) to every connected monitor.
#
# hyprpaper links against librsvg, libpng, libjpeg, libwebp and libjxl
# directly (confirmed via `ldd`) and its `wallpaper` IPC request takes
# a fit_mode (confirmed via `hyprctl hyprpaper --help`), so it cover-
# scales whatever format the file is on its own -- confirmed directly
# this session by applying an SVG to a live monitor with fit_mode
# "cover" and checking `hyprctl hyprpaper listactive`. That means this
# script never needs to pre-rasterize or crop anything itself; it just
# hands the (possibly recolored, see below) file straight to hyprpaper
# for every connected monitor.
#
# An SVG selection is expected to follow one convention: an element
# with id="sobarch-bg" and one with id="sobarch-accent", each carrying
# a plain fill="#RRGGBB" attribute (not a `style="fill:...` shorthand,
# see the substitution below for why). Those two get recolored to the
# current theme's base00/base0D before handing the file to hyprpaper;
# a plain raster image is used as-is, no recoloring possible or
# expected. sobarch's own reference design (branding/sobarch-
# wallpaper.svg, deployed to the backgrounds dir above) follows this
# convention; anyone can drop their own SVG or image alongside it.
#
# Run both as the sobarch-waybar-css tinty item's hook (colors
# changed, see that item's own comment in config.toml for why its hook
# and not a dedicated one) and from hyprland.lua's monitor.added/
# monitor.removed handlers (monitor set changed); always re-applies to
# every connected monitor fresh rather than diffing against previous
# state.
set -euo pipefail

CURRENT_FILE="$HOME/.config/sobarch/current-wallpaper"
DEFAULT_WALLPAPER="$HOME/.local/share/backgrounds/sobarch-wallpaper.svg"
COLORS_CSS="$HOME/.config/waybar/colors.css"
WORKDIR="$HOME/.cache/sobarch"

command -v hyprctl >/dev/null 2>&1 || exit 0

wallpaper="$DEFAULT_WALLPAPER"
[[ -f "$CURRENT_FILE" ]] && wallpaper="$(<"$CURRENT_FILE")"
[[ -f "$wallpaper" ]] || exit 0

path_to_apply="$wallpaper"

if [[ "$wallpaper" == *.svg ]]; then
    if [[ -f "$COLORS_CSS" ]]; then
        base00=$(grep -oP '@define-color base00 #\K[0-9A-Fa-f]{6}' "$COLORS_CSS" | head -n1)
        base0d=$(grep -oP '@define-color base0D #\K[0-9A-Fa-f]{6}' "$COLORS_CSS" | head -n1)
    fi
    if [[ -n "${base00:-}" && -n "${base0d:-}" ]]; then
        mkdir -p "$WORKDIR"
        recolored="$WORKDIR/wallpaper.svg"
        # Rewrites fill="#......" to the current theme's colors, but
        # only within whichever element actually carries
        # id="sobarch-bg"/id="sobarch-accent". Scans the whole file as
        # one string rather than line by line: Inkscape sometimes closes
        # one element and opens the next on the very same line (e.g.
        # `.../><path`), which a line-oriented tag scan can miss
        # entirely, silently leaving that element unrecolored.
        awk -v bg="$base00" -v accent="$base0d" '
            BEGIN { RS = "\0" }
            {
                remaining = $0
                while (match(remaining, /<[A-Za-z][^>]*>/)) {
                    printf "%s", substr(remaining, 1, RSTART - 1)
                    tag = substr(remaining, RSTART, RLENGTH)
                    if (index(tag, "id=\"sobarch-bg\"") > 0) {
                        gsub(/fill="#[0-9A-Fa-f]{6}"/, "fill=\"#" bg "\"", tag)
                    } else if (index(tag, "id=\"sobarch-accent\"") > 0) {
                        gsub(/fill="#[0-9A-Fa-f]{6}"/, "fill=\"#" accent "\"", tag)
                    }
                    printf "%s", tag
                    remaining = substr(remaining, RSTART + RLENGTH)
                }
                printf "%s", remaining
            }
        ' "$wallpaper" >"$recolored"
        path_to_apply="$recolored"
    fi
fi

while read -r name; do
    [[ -z "$name" ]] && continue
    hyprctl hyprpaper wallpaper "${name},${path_to_apply},cover" >/dev/null
done < <(hyprctl monitors | awk '/^Monitor / { print $2 }')
