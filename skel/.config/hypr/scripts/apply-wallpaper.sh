#!/usr/bin/env bash
# Applies whatever wallpaper is currently selected (~/.config/sobarch/
# current-wallpaper, a plain text file holding one absolute path,
# written by wallpaper-menu.sh; defaults to sobarch's own shipped
# ~/.local/share/backgrounds/sobarch-wallpaper.svg if that file doesn't
# exist yet) to every connected monitor.
#
# hyprpaper links against librsvg, libpng, libjpeg, libwebp and libjxl
# directly (confirmed via `ldd`) and its `wallpaper` IPC request takes
# a fit_mode (confirmed via `hyprctl hyprpaper --help`), and its own
# raster-image cover-scaling genuinely works (confirmed directly this
# session). Its own SVG decoding does not, though: a file with a
# separate background rect plus a mark path rendered as flat black
# straight through hyprpaper's IPC, while rasterizing that exact same
# file to PNG first and handing hyprpaper the PNG displayed correctly
# (also confirmed directly this session, on a real machine, after
# every other part of this pipeline, recoloring included, checked out
# fine). So an SVG selection is always rasterized to PNG here before
# ever reaching hyprpaper. A convention-following SVG (see below) is
# rasterized once per distinct monitor size, fitted to that monitor
# itself (see fit_to_monitor); anything else is rasterized once at the
# design's own native resolution and left to hyprpaper's own (working)
# raster cover-scaling, the same way an ordinary JPG/PNG wallpaper is.
#
# An SVG selection is expected to follow one convention: an element
# with id="sobarch-bg" and one with id="sobarch-accent", each carrying
# a plain fill="#RRGGBB" attribute (not a `style="fill:...` shorthand,
# see the substitution below for why). Those two get recolored to the
# current theme's base00/base0D before rasterizing; a plain raster
# image is used as-is, no recoloring possible or expected. sobarch's
# own reference design (branding/sobarch-wallpaper.svg, deployed to
# the backgrounds dir above) follows this convention; anyone can drop
# their own SVG or image alongside it.
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
WORKDIR="$HOME/.cache/sobarch/wallpaper"

command -v hyprctl >/dev/null 2>&1 || exit 0

wallpaper="$DEFAULT_WALLPAPER"
[[ -f "$CURRENT_FILE" ]] && wallpaper="$(<"$CURRENT_FILE")"
[[ -f "$wallpaper" ]] || exit 0

# WORKDIR holds only this script's own intermediate renders (the
# recolored SVG and its PNG), so it's emptied outright on every run
# rather than pruned selectively: nothing in it ever needs to survive
# past the render that replaces it. It's its own subdirectory, not
# ~/.cache/sobarch itself, since themes-menu.sh keeps its swatches
# there. The second rm drops renders left directly in ~/.cache/sobarch
# by versions of this script from before the subdirectory existed.
rm -rf "$WORKDIR"
rm -f "$HOME/.cache/sobarch"/wallpaper.svg "$HOME/.cache/sobarch"/wallpaper*.png

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

    command -v rsvg-convert >/dev/null 2>&1 || exit 0
    mkdir -p "$WORKDIR"
    # hyprpaper caches decoded images by path and never re-reads a path
    # it has already loaded (v0.8.4 has no unload/reload request either,
    # confirmed via `hyprctl hyprpaper --help`): overwriting one fixed
    # wallpaper.png in place on a theme switch left every monitor
    # showing the previous theme's render until hyprpaper restarted.
    # Naming the PNG after a checksum of the exact SVG being rasterized
    # gives every distinct theme/source combination its own path, while
    # an unchanged one (e.g. monitor.added re-applying) keeps the same
    # path hyprpaper already has (re-rendered identically, since WORKDIR
    # was emptied above).
    sum=$(cksum <"$path_to_apply" | cut -d' ' -f1)
    rasterized="$WORKDIR/wallpaper-$sum.png"
    rsvg-convert "$path_to_apply" -o "$rasterized" || exit 0
    svg_to_fit="$path_to_apply"
    path_to_apply="$rasterized"

    # Per-monitor fitting needs a known solid color to fill whatever the
    # design's own canvas doesn't cover, which only a convention-
    # following SVG guarantees (its sobarch-bg, recolored to base00).
    if [[ -n "${base00:-}" ]] && grep -q 'id="sobarch-bg"' "$wallpaper"; then
        fill_color="#$base00"
        # The native render's pixel size, read straight from its PNG
        # IHDR chunk (bytes 16-23: big-endian width, then height).
        read -r native_w native_h < <(od -An -tu1 -j16 -N8 "$rasterized" |
            awk '{ print $1*16777216 + $2*65536 + $3*256 + $4, $5*16777216 + $6*65536 + $7*256 + $8 }')
    fi
fi

# hyprpaper's own cover-scaling of the single native render looked wrong
# on any monitor whose aspect ratio differs from the design's (a 1080x1920
# portrait monitor next to a 1920x1080 landscape one blew the 16:9 design
# up ~1.8x and cropped its middle, slicing the mark apart). Instead, this
# renders the design to the monitor's exact pixel size, scaled so the
# canvas's short edge matches the monitor's short edge, centered, with
# fill_color behind it. The mark then comes out the same size on every
# monitor sharing a short edge whatever its orientation (on a portrait
# monitor only the canvas's empty left/right margins get cropped), and
# proportionally larger on a bigger one. One render per distinct size,
# shared by every monitor of that size; echoes the path to apply.
fit_to_monitor() {
    local w=$1 h=$2 short native_short rw rh out
    out="$WORKDIR/wallpaper-$sum-${w}x${h}.png"
    if [[ ! -f "$out" ]]; then
        short=$((w < h ? w : h))
        native_short=$((native_w < native_h ? native_w : native_h))
        rw=$((native_w * short / native_short))
        rh=$((native_h * short / native_short))
        # --left=/--top= (not a separate argument): either can be
        # negative, which rsvg-convert's parser would otherwise take
        # for an unknown flag.
        rsvg-convert --page-width "$w" --page-height "$h" -w "$rw" -h "$rh" \
            --left="$(((w - rw) / 2))" --top="$(((h - rh) / 2))" \
            -b "$fill_color" "$svg_to_fit" -o "$out" || out="$path_to_apply"
    fi
    echo "$out"
}

# hyprland.lua's own autostart launches `hyprpaper &` in the background
# (one exec_cmd among several -- waybar, mako, hypridle, udiskie all
# starting at the same moment) and `tinty init` (whose sobarch-waybar-css
# hook is what runs this very script) as a separate, independently
# scheduled exec_cmd right after. Nothing orders the two against each
# other, so on a login busy enough to slow hyprpaper's own startup, this
# script's first real run can hit hyprctl before hyprpaper's IPC socket
# exists yet -- under `set -e`, that failure used to abort the whole
# script outright, leaving every monitor with no wallpaper set until the
# next full re-login or theme switch happened to run late enough to win
# the race. Retried here instead, bounded to 2s (same shape as
# sobarch-waybar-jsonc's own wait-for-old-process-exit hook in
# config.toml): a real "hyprpaper isn't installed/running at all" case
# still degrades to no wallpaper rather than hanging login, same as this
# script's other `|| exit 0` guards above.
set_wallpaper() {
    local attempt
    for attempt in {1..20}; do
        hyprctl hyprpaper wallpaper "$1" >/dev/null 2>&1 && return 0
        sleep 0.1
    done
    return 1
}

# Each monitor's name plus its effective pixel size: the active mode's
# width/height, swapped for an odd `transform` (90/270 degrees, flipped
# or not), since a rotated monitor's mode line still reports its
# unrotated panel size.
while read -r name width height; do
    [[ -z "$name" ]] && continue
    monitor_path="$path_to_apply"
    [[ -n "${fill_color:-}" ]] && monitor_path="$(fit_to_monitor "$width" "$height")"
    set_wallpaper "${name},${monitor_path},cover" || true
done < <(hyprctl monitors | awk '
    /^Monitor / { name = $2 }
    /^[[:space:]]+[0-9]+x[0-9]+@/ { split($1, mode, /[x@]/); w = mode[1]; h = mode[2] }
    /^[[:space:]]+transform:/ { if ($2 % 2) { t = w; w = h; h = t }; print name, w, h }
')
