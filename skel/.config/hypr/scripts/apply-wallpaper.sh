#!/usr/bin/env bash
# Applies the selected wallpaper (~/.config/sobarch/current-wallpaper) to
# every monitor. Run by the tinty colors hook and on monitor hotplug.
#
# SVGs are rasterized here because hyprpaper renders some SVGs as flat
# black. An SVG with fill="#RRGGBB" on elements id="sobarch-bg" and
# id="sobarch-accent" is recolored to base00/base0D and fitted per monitor.
set -euo pipefail

CURRENT_FILE="$HOME/.config/sobarch/current-wallpaper"
DEFAULT_WALLPAPER="$HOME/.local/share/backgrounds/sobarch-wallpaper.svg"
COLORS_CSS="$HOME/.config/waybar/colors.css"
WORKDIR="$HOME/.cache/sobarch/wallpaper"

command -v hyprctl >/dev/null 2>&1 || exit 0

wallpaper="$DEFAULT_WALLPAPER"
[[ -f "$CURRENT_FILE" ]] && wallpaper="$(<"$CURRENT_FILE")"
[[ -f "$wallpaper" ]] || exit 0

# Hotplug (a KVM switch) fires a burst of events: the last one wins after a
# short quiet period, and runs never overlap.
RUNTIME="${XDG_RUNTIME_DIR:-/tmp}"
token="$$-$RANDOM"
echo "$token" >"$RUNTIME/sobarch-wallpaper.token"
sleep 2
[[ "$(<"$RUNTIME/sobarch-wallpaper.token")" == "$token" ]] || exit 0
exec 9>"$RUNTIME/sobarch-wallpaper.lock"
flock 9

# Cleans up renders from older versions of this script.
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
        # Scan the whole file as one string: Inkscape can put several
        # tags on one line.
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
    # hyprpaper never reloads a path it has already loaded, so name the
    # PNG after the SVG's checksum.
    sum=$(cksum <"$path_to_apply" | cut -d' ' -f1)
    rasterized="$WORKDIR/wallpaper-$sum.png"
    find "$WORKDIR" -maxdepth 1 -type f ! -name "wallpaper-$sum*" ! -name wallpaper.svg -delete
    [[ -f "$rasterized" ]] || rsvg-convert "$path_to_apply" -o "$rasterized" || exit 0
    svg_to_fit="$path_to_apply"
    path_to_apply="$rasterized"

    # Per-monitor fitting needs a known solid color to fill whatever the
    # design's own canvas doesn't cover, which only a convention-
    # following SVG guarantees (its sobarch-bg, recolored to base00).
    if [[ -n "${base00:-}" ]] && grep -q 'id="sobarch-bg"' "$wallpaper"; then
        fill_color="#$base00"
        # Width and height from the PNG IHDR chunk (bytes 16-23).
        read -r native_w native_h < <(od -An -tu1 -j16 -N8 "$rasterized" |
            awk '{ print $1*16777216 + $2*65536 + $3*256 + $4, $5*16777216 + $6*65536 + $7*256 + $8 }')
    fi
fi

# Render at the monitor's exact size, scaling the canvas's short edge to
# the monitor's short edge, so the mark keeps its size in portrait mode.
# Prints the path to apply.
fit_to_monitor() {
    local w=$1 h=$2 short native_short rw rh out
    out="$WORKDIR/wallpaper-$sum-${w}x${h}.png"
    if [[ ! -f "$out" ]]; then
        short=$((w < h ? w : h))
        native_short=$((native_w < native_h ? native_w : native_h))
        rw=$((native_w * short / native_short))
        rh=$((native_h * short / native_short))
        # --left=/--top= form so a negative value isn't parsed as a flag.
        rsvg-convert --page-width "$w" --page-height "$h" -w "$rw" -h "$rh" \
            --left="$(((w - rw) / 2))" --top="$(((h - rh) / 2))" \
            -b "$fill_color" "$svg_to_fit" -o "$out" || out="$path_to_apply"
    fi
    echo "$out"
}

# hyprpaper's IPC socket may not exist yet at login, so retry for 2s.
set_wallpaper() {
    local attempt
    for attempt in {1..20}; do
        timeout 2 hyprctl hyprpaper wallpaper "$1" >/dev/null 2>&1 && return 0
        # Timed out: hyprpaper is hung, retrying won't help.
        [[ $? -eq 124 ]] && return 1
        sleep 0.1
    done
    return 1
}

active=$(timeout 2 hyprctl hyprpaper listactive 2>/dev/null || true)

# Rotated monitors still report the unrotated mode, so swap w/h for odd transforms.
while read -r name width height; do
    [[ -z "$name" || "$name" == FALLBACK ]] && continue
    monitor_path="$path_to_apply"
    [[ -n "${fill_color:-}" ]] && monitor_path="$(fit_to_monitor "$width" "$height")"
    grep -F "$monitor_path" <<<"$active" | grep -qF "$name" && continue
    set_wallpaper "${name},${monitor_path},cover" || true
done < <(hyprctl monitors | awk '
    /^Monitor / { name = $2 }
    /^[[:space:]]+[0-9]+x[0-9]+@/ { split($1, mode, /[x@]/); w = mode[1]; h = mode[2] }
    /^[[:space:]]+transform:/ { if ($2 % 2) { t = w; w = h; h = t }; print name, w, h }
')
