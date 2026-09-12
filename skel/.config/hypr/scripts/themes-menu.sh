#!/usr/bin/env bash
# Lists every base16/base24/tinted8 scheme tinty knows about (populated
# by `tinty install`, run self-healingly from hyprland.lua's autostart
# hook on every login -- there is no separate tinty-git post-install
# step) and applies the chosen one. Each tinty
# config.toml item's own `hook` (see
# ~/.config/tinted-theming/tinty/config.toml) handles reloading the app
# it themes; nothing extra to do here beyond the apply itself.
set -euo pipefail

# md-format_color_fill: same icon setup-menu.sh's own "Themes" entry uses.
TITLE=$'\U000F0266'"  sobarch: themes"

if ! command -v tinty >/dev/null 2>&1; then
    notify-send -u critical "$TITLE" \
        "tinty isn't installed (Sobarch -> Update Config, to fetch base-required packages)."
    exit 1
fi

# tinty list prints raw <scheme_system>-<scheme_name> ids (e.g.
# base16-atelier-forest-light), which read as clutter in a picker;
# reformat each into "Pretty Name" (only tagging non-base16 systems,
# since base16 is the common case) while keeping the raw id around
# (tab-separated, hidden via --with-nth) for the actual tinty apply call.
line=$(tinty list | awk -F'-' '
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
    }' | sort -f | fuzzel --dmenu --with-nth=1 --prompt "theme: ")
[[ -n "${line:-}" ]] || exit 0

pretty="${line%%$'\t'*}"
raw="${line#*$'\t'}"

if tinty apply "$raw"; then
    notify-send "$TITLE" "Applied $pretty."
else
    notify-send -u critical "$TITLE" "Failed to apply $pretty."
fi
