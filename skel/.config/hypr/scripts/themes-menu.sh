#!/usr/bin/env bash
# Theme picker over every scheme tinty knows. Each tinty item's own hook
# reloads its app. Stays open after applying, so Enter, Down, Enter
# previews themes in turn.

source "$HOME/.config/hypr/scripts/menu-lib.sh"

MENU_TITLE="sobarch: themes"
MENU_ICON="palette.svg"
MENU_PLACEHOLDER="Search themes"

if ! command -v tinty >/dev/null 2>&1; then
    menu_notify "tinty isn't installed (Sobarch -> Update System, to fetch base-required packages)." critical
    exit 1
fi

# Picks up edits to local.toml; a broken one is skipped and reported.
if cfg_err=$(/usr/local/lib/sobarch/tinty-config.sh 2>&1) && [ -n "$cfg_err" ]; then
    menu_notify "$(head -n 6 <<<"$cfg_err")" critical
fi

# "base16-atelier-forest-light" -> "Atelier Forest Light", raw id kept as the row id.
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

# A cached 4-color swatch per scheme. Building 500+ swatches takes too
# long to do inline, so missing ones are generated in the background for
# the next open. Without rsvg-convert the list just has no swatches.
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

# Rows are built once; a pick only moves the "current" marker.
current=$(tinty current 2>/dev/null)
declare -A row_of
menu_reset
while IFS=$'\t' read -r pretty raw; do
    [[ -n "$raw" ]] || continue
    swatch=""
    [[ "$have_rsvg" = 1 && -f "$SWATCH_DIR/$raw.png" ]] && swatch="$SWATCH_DIR/$raw.png"
    row_of["$raw"]=${#MENU_IDS[@]}
    menu_add "$raw" "$pretty" "$swatch" "$([[ "$raw" = "$current" ]] && echo current)"
done <<<"$entries"

# Copy fuzzel's colors first so the picker reopens in the new scheme at
# once, and run the slow full apply in the background. Waiting on the
# previous apply keeps two applies from interleaving.
FUZZEL_COLORS="$HOME/.config/sobarch/tinty-templates/fuzzel/colors"
apply_pid=""
apply_scheme() {
    [[ -n "$apply_pid" ]] && wait "$apply_pid"
    [[ -f "$FUZZEL_COLORS/$1.ini" ]] && cp "$FUZZEL_COLORS/$1.ini" "$HOME/.config/fuzzel/colors.ini"
    menu_run tinty apply "$1" &
    apply_pid=$!
}

selected="$current"
while menu_show theme "" "$selected"; do
    selected="$MENU_ID"
    [[ "$MENU_ID" = "$current" ]] && continue
    [[ -n "$current" && -n "${row_of[$current]:-}" ]] && MENU_STATES[${row_of[$current]}]=""
    MENU_STATES[${row_of[$MENU_ID]}]="current"
    current="$MENU_ID"
    apply_scheme "$MENU_ID"
done
[[ -n "$apply_pid" ]] && wait "$apply_pid"
