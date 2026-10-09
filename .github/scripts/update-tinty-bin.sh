#!/usr/bin/env bash
# Keeps packages/custom/tinty-bin current with upstream's GitHub
# releases. The AUR-based update check (scripts/aur-sync/
# check-aur-updates.sh) can't cover it: tinty-bin lives in
# packages/custom/ because the AUR has no such package, only tinty-git.
#
#   update-tinty-bin.sh --check   prints "tinty-bin <pinned> <latest>"
#                                 if upstream has a newer release,
#                                 nothing otherwise
#   update-tinty-bin.sh           rewrites pkgver, pkgrel and both
#                                 checksums for the latest release, and
#                                 regenerates .SRCINFO
#
# Must run as a non-root user (makepkg). Latest release is found via
# the /releases/latest redirect (no API rate limit, no jq), which
# skips prereleases. The binary tarball's checksum is cross-checked
# against the .sha256 asset published beside it, which catches a
# corrupted download only: a compromised release would publish a
# matching checksum, so the PR this feeds still needs human review.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

pkg=packages/custom/tinty-bin
base=https://github.com/tinted-theming/tinty

current="$(grep -oP '^pkgver=\K.*' "$pkg/PKGBUILD")"
tag_url="$(curl -fsSIL -o /dev/null -w '%{url_effective}' "$base/releases/latest")"
latest="${tag_url##*/v}"
if [[ ! "$latest" =~ ^[0-9]+(\.[0-9]+)+$ ]]; then
    echo "update-tinty-bin: unexpected latest release URL: $tag_url" >&2
    exit 1
fi

if (( $(vercmp "$latest" "$current") <= 0 )); then
    exit 0
fi

if [[ "${1:-}" == "--check" ]]; then
    echo "tinty-bin $current $latest"
    exit 0
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

curl -fsSL -o "$work/bin.tar.gz" "$base/releases/download/v$latest/tinty-x86_64-unknown-linux-gnu.tar.gz"
curl -fsSL -o "$work/src.tar.gz" "$base/archive/refs/tags/v$latest.tar.gz"
bin_sha="$(sha256sum "$work/bin.tar.gz" | cut -d' ' -f1)"
src_sha="$(sha256sum "$work/src.tar.gz" | cut -d' ' -f1)"

published="$(curl -fsSL "$base/releases/download/v$latest/tinty-x86_64-unknown-linux-gnu.sha256" | cut -d' ' -f1)"
if [[ "$published" != "$bin_sha" ]]; then
    echo "update-tinty-bin: binary tarball sha256 $bin_sha doesn't match the published $published" >&2
    exit 1
fi

# The PKGBUILD's two sha256sums entries, in source order: binary, then
# source archive.
mapfile -t old_shas < <(grep -oE '[0-9a-f]{64}' "$pkg/PKGBUILD")
if ((${#old_shas[@]} != 2)); then
    echo "update-tinty-bin: expected exactly 2 checksums in $pkg/PKGBUILD, found ${#old_shas[@]}" >&2
    exit 1
fi

sed -i \
    -e "s/^pkgver=.*/pkgver=$latest/" \
    -e "s/^pkgrel=.*/pkgrel=1/" \
    -e "s/${old_shas[0]}/$bin_sha/" \
    -e "s/${old_shas[1]}/$src_sha/" \
    "$pkg/PKGBUILD"

(cd "$pkg" && makepkg --printsrcinfo > .SRCINFO)

echo "update-tinty-bin: $current -> $latest"
