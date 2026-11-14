#!/usr/bin/env bash
# Renders every scheme for each local tinty item under tinty-templates/.
# `tinty apply` never renders, so this must run before apply/init.
#
# Re-run `tinty install` here: hyprland.lua only installs when nothing is
# installed yet, so items added by a later skel update would stay unregistered.
# Update System runs this, so it also pulls new schemes and templates.

set -euo pipefail

TEMPLATES_DIR="$HOME/.config/sobarch/tinty-templates"

command -v tinty >/dev/null 2>&1 || exit 0
[[ -d "$TEMPLATES_DIR" ]] || exit 0

# Regenerate first: the base config may have changed with a skel update.
/usr/local/lib/sobarch/tinty-config.sh

tinty install || true

# tinty reads every YAML file in an extra scheme repo, so one that also holds
# templates or other YAML fails to apply. Keep only the scheme folders.
# Local-path extras are symlinks to the user's own folder and are left alone.
for repo in "${XDG_DATA_HOME:-$HOME/.local/share}"/tinted-theming/tinty/scheme-repos/*/; do
    repo="${repo%/}"
    if [[ "${repo##*/}" != schemes && ! -L "$repo" && -d "$repo/.git" ]]; then
        git -C "$repo" sparse-checkout set base16 base24 tinted8 || true
    fi
done

# install never refreshes what's already there. Offline is not an error.
tinty update || true

for template_dir in "$TEMPLATES_DIR"/*/; do
    tinty build "${template_dir%/}"
done
