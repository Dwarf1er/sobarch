#!/usr/bin/env bash
# Renders every scheme for each local tinty item under tinty-templates/.
# `tinty apply` never renders, so this must run before apply/init.
#
# Re-run `tinty install` here: hyprland.lua only installs when nothing is
# installed yet, so items added by a later skel update would stay unregistered.

set -euo pipefail

TEMPLATES_DIR="$HOME/.config/sobarch/tinty-templates"

command -v tinty >/dev/null 2>&1 || exit 0
[[ -d "$TEMPLATES_DIR" ]] || exit 0

tinty install || true

for template_dir in "$TEMPLATES_DIR"/*/; do
    tinty build "${template_dir%/}"
done
