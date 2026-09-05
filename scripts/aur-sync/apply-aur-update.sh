#!/usr/bin/env bash
# Replaces packages/aur/NAME/'s vendored files with a fresh clone of
# that package's AUR git repo, then regenerates .SRCINFO. Mutates the
# working tree only; the actual review (diff, namcap, branch/PR) is
# .github/workflows/aur.yml's job, not this script's.
#
# Must run as a non-root user: makepkg refuses outright to run as root
# (no override flag), same constraint aur-sync.sh's own build step
# works around with a dedicated build user.

set -euo pipefail
shopt -s inherit_errexit

name="${1:?usage: apply-aur-update.sh PKGNAME}"

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

dest="packages/aur/$name"
[[ -d "$dest" ]] || { echo "apply-aur-update: $dest does not exist" >&2; exit 1; }

clone_dir="$(mktemp -d)"
trap 'rm -rf "$clone_dir"' EXIT

git clone --depth 1 "https://aur.archlinux.org/${name}.git" "$clone_dir"

# Full replace, not a merge: whatever AUR currently tracks for this
# pkgbase is the new vendored snapshot, including any file it stopped
# shipping.
rm -rf "${dest:?}"/*
find "$clone_dir" -mindepth 1 -maxdepth 1 -not -name '.git' -exec cp -a {} "$dest/" \;

(cd "$dest" && makepkg --printsrcinfo > .SRCINFO)

echo "apply-aur-update: $name staged from $(git -C "$clone_dir" rev-parse --short HEAD)"
