#!/usr/bin/env bash
# Moves packages/custom/vesktop-integrity-launch's pinned _commit to
# upstream HEAD.
#
#   update-vesktop-integrity-launch.sh --check   prints "<name> <pinned> <head>" if different
#   update-vesktop-integrity-launch.sh           bumps _commit, pkgver, pkgrel and .SRCINFO
#
# pkgver is HEAD's UTC commit date; a second commit on the same day bumps
# pkgrel instead so the version always increases.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

pkg=packages/custom/vesktop-integrity-launch
url="$(grep -oP '^url="\K[^"]+' "$pkg/PKGBUILD")"

pinned="$(grep -oP '^_commit=\K[0-9a-f]{40}$' "$pkg/PKGBUILD")"
head="$(git ls-remote "$url.git" HEAD | cut -f1)"
if [[ ! "$head" =~ ^[0-9a-f]{40}$ ]]; then
    echo "update-vesktop-integrity-launch: couldn't resolve upstream HEAD for $url" >&2
    exit 1
fi

[[ "$head" == "$pinned" ]] && exit 0

if [[ "${1:-}" == "--check" ]]; then
    echo "vesktop-integrity-launch $pinned $head"
    exit 0
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
git clone -q --filter=blob:none --no-checkout "$url.git" "$work/upstream"
head_date="$(TZ=UTC git -C "$work/upstream" log -1 "$head" --format=%cd --date=format:%Y%m%d)"

current_ver="$(grep -oP '^pkgver=\K.*' "$pkg/PKGBUILD")"
current_rel="$(grep -oP '^pkgrel=\K.*' "$pkg/PKGBUILD")"
if [[ "$head_date" == "$current_ver" ]]; then
    new_ver="$current_ver"
    new_rel=$((current_rel + 1))
else
    new_ver="$head_date"
    new_rel=1
fi

sed -i \
    -e "s/^_commit=.*/_commit=$head/" \
    -e "s/^pkgver=.*/pkgver=$new_ver/" \
    -e "s/^pkgrel=.*/pkgrel=$new_rel/" \
    "$pkg/PKGBUILD"

(cd "$pkg" && makepkg --printsrcinfo > .SRCINFO)

echo "update-vesktop-integrity-launch: ${pinned:0:7} -> ${head:0:7} ($new_ver-$new_rel)"
