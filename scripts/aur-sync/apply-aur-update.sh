#!/usr/bin/env bash
# Replaces packages/aur/NAME/ with a fresh clone of its AUR repo and
# regenerates .SRCINFO. Review happens in .github/workflows/aur.yml.
# makepkg refuses to run as root.

set -euo pipefail
shopt -s inherit_errexit

name="${1:?usage: apply-aur-update.sh PKGNAME}"

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

dest="packages/aur/$name"
[[ -d "$dest" ]] || { echo "apply-aur-update: $dest does not exist" >&2; exit 1; }

clone_dir="$(mktemp -d)"
trap 'rm -rf "$clone_dir"' EXIT

git clone --depth 1 "https://aur.archlinux.org/${name}.git" "$clone_dir"

# Full replace, so files the AUR stopped shipping are dropped too.
rm -rf "${dest:?}"/*
find "$clone_dir" -mindepth 1 -maxdepth 1 -not -name '.git' -exec cp -a {} "$dest/" \;

(cd "$dest" && makepkg --printsrcinfo > .SRCINFO)

echo "apply-aur-update: $name staged from $(git -C "$clone_dir" rev-parse --short HEAD)"
