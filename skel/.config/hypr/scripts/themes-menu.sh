#!/usr/bin/env bash
# Lists every base16/base24/tinted8 scheme tinty knows about (populated
# by `tinty install`, run self-healingly from hyprland.lua's autostart
# hook on every login -- there is no separate tinty post-install
# step) and applies the chosen one. Each tinty
# config.toml item's own `hook` (see
# ~/.config/tinted-theming/tinty/config.toml) handles reloading the app
# it themes; nothing extra to do here beyond the apply itself.
#
# Stays open after applying, cursor kept on the scheme just applied and
# marked current: an apply takes well under a second, and every fuzzel
# launch re-reads its own colors.ini, so the picker itself reopens in
# the new theme. Browsing is Enter, Down, Enter... as a live preview.

source "$HOME/.config/hypr/scripts/menu-lib.sh"

MENU_TITLE="sobarch: themes"
MENU_ICON="palette.svg"
MENU_PLACEHOLDER="Search themes"

if ! command -v tinty >/dev/null 2>&1; then
    menu_notify "tinty isn't installed (Sobarch -> Update System, to fetch base-required packages)." critical
    exit 1
fi

# tinty list prints raw <scheme_system>-<scheme_name> ids (e.g.
# base16-atelier-forest-light), which read as clutter in a picker;
# reformat each into "Pretty Name" (only tagging non-base16 systems,
# since base16 is the common case) while keeping the raw id around
# (tab-separated; it becomes the row id) for the actual tinty apply call.
entries=$(tinty list | awk -F'-' '
    length($0) == 0 { next }
    {
        raw = $0
        sys = $1
        name = substr(raw, length(sys) + 2)
        gsub(/-/, " ", name)
        n = split(name, words, " ")
        pretty = ""
        for (i = 1; i <= n; i++)
            pretty = pretty (i > 1 ? " " : "") toupper(substr(words[i], 1, 1)) substr(words[i], 2)
        if (sys == "base24") pretty = pretty " (24-color)"
        else if (sys == "tinted8") pretty = pretty " (8-color)"
        print pretty "\t" raw
    }' | sort -f)

# A 4-color swatch per scheme (background/foreground/red/blue, the same
# four `tinty info` already reports as base00/base05/base08/base0D),
# cached by raw scheme id so a warm cache costs nothing but a stat.
# Same best-effort rsvg-convert dependency apply-wallpaper.sh's own SVG
# rasterizing already relies on: a missing rsvg-convert just means this
# menu falls back to a plain list, not a broken one. Unlike wallpaper
# thumbnails, there's no existing image file per theme to point fuzzel
# at, so this builds one: a tiny inline SVG, rasterized the same way an
# SVG wallpaper already is.
#
# tinty knows 500+ schemes; generating a swatch for every one of them
# synchronously (confirmed directly: ~10-20s for a cold cache) would
# make the menu itself feel broken. Only a cache hit is used to
# decorate THIS run's list; anything missing shows as a plain row for
# now, and a detached background pass (below) fills the cache in for
# every future open -- self-healing the same way tinty's own install
# step already is, not a new persistent service.
SWATCH_DIR="$HOME/.cache/sobarch/theme-swatches"
have_rsvg=0
command -v rsvg-convert >/dev/null 2>&1 && have_rsvg=1

generate_swatch() {
    local raw="$1" out="$SWATCH_DIR/$raw.png"
    local colors
    mapfile -t colors < <(tinty info "$raw" 2>/dev/null | grep -oP '\bbase0[058D]\s*\|\s*\K#[0-9a-fA-F]{6}')
    [[ "${#colors[@]}" -eq 4 ]] || return 1
    local svg_tmp
    svg_tmp="$(mktemp --suffix=.svg)"
    cat > "$svg_tmp" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64">
<rect width="64" height="64" fill="${colors[0]}"/>
<rect x="32" width="32" height="32" fill="${colors[2]}"/>
<rect y="32" width="32" height="32" fill="${colors[3]}"/>
<rect x="32" y="32" width="32" height="32" fill="${colors[1]}"/>
</svg>
SVG
    rsvg-convert "$svg_tmp" -o "$out" 2>/dev/null
    rm -f "$svg_tmp"
}

missing_raws=""
if [[ "$have_rsvg" = 1 ]]; then
    mkdir -p "$SWATCH_DIR"
    while IFS=$'\t' read -r _ raw; do
        [[ -n "$raw" ]] || continue
        [[ -f "$SWATCH_DIR/$raw.png" ]] || missing_raws+="$raw"$'\n'
    done <<<"$entries"

    if [[ -n "$missing_raws" ]]; then
        (
            while IFS= read -r raw; do
                [[ -n "$raw" ]] || continue
                generate_swatch "$raw"
            done <<<"$missing_raws"
        ) </dev/null >/dev/null 2>&1 &
        disown 2>/dev/null || true
    fi
fi

selected=""
while :; do
    current=$(tinty current 2>/dev/null)
    [[ -n "$selected" ]] || selected="$current"
    menu_reset
    while IFS=$'\t' read -r pretty raw; do
        [[ -n "$raw" ]] || continue
        swatch=""
        [[ "$have_rsvg" = 1 && -f "$SWATCH_DIR/$raw.png" ]] && swatch="$SWATCH_DIR/$raw.png"
        menu_add "$raw" "$pretty" "$swatch" "$([[ "$raw" = "$current" ]] && echo current)"
    done <<<"$entries"
    menu_show theme "" "$selected" || break
    selected="$MENU_ID"
    menu_run tinty apply "$MENU_ID"
done
