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

choice=$(tinty list | fuzzel --dmenu --prompt "theme: ")
[[ -n "${choice:-}" ]] || exit 0

if tinty apply "$choice"; then
    notify-send "$TITLE" "Applied $choice."
else
    notify-send -u critical "$TITLE" "Failed to apply $choice."
fi
