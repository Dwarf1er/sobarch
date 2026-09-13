#!/usr/bin/env bash
# Renders every scheme for each locally-authored tinty item under
# ~/.config/sobarch/tinty-templates/ (see that directory's
# templates/config.yaml + default.mustache pairs). `tinty apply` only
# ever copies an already-rendered file out of an item's `themes-dir`;
# it never renders one itself, so this has to run before `tinty
# apply`/`init` can find anything there. Run from hyprland.lua's
# self-healing autostart hook right after a first `tinty install`, and
# from update-config-menu.sh after every apply-skel.sh run, since a
# skel update can change these templates.
#
# Local items only (globbed straight from the directory, not a
# separately maintained list that could drift): the two upstream
# items in config.toml (tinted-terminal-kitty, base16-hyprland-lua)
# ship their own pre-rendered themes-dir already, nothing to build
# here.
#
# `tinty install` re-run here (best-effort, not just relied on from
# hyprland.lua's autostart hook): that hook only installs when `tinty
# list` is completely empty, so it never fires again once anything's
# installed -- a config.toml item added by a later skel update (a real
# case hit directly this session: sobarch-waybar-css) would otherwise
# stay silently unregistered under
# ~/.local/share/tinted-theming/tinty/repos/ until something else
# happened to trigger `tinty install`, and `apply` would fail on it
# indefinitely. Failure here is swallowed (offline, GitHub hiccup) so
# it doesn't block building whatever's already installed -- the same
# reasoning update-config-menu.sh already applies to its own
# refresh/curl checks.

set -euo pipefail

TEMPLATES_DIR="$HOME/.config/sobarch/tinty-templates"

command -v tinty >/dev/null 2>&1 || exit 0
[[ -d "$TEMPLATES_DIR" ]] || exit 0

tinty install || true

for template_dir in "$TEMPLATES_DIR"/*/; do
    tinty build "${template_dir%/}"
done
