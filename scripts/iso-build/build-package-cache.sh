#!/usr/bin/env bash
# Builds a local pacman repo carrying every package the prebuilt ISO
# wants cached (official + packages/aur/ + packages/custom/), so a real
# install resolves them from the ISO's own airootfs instead of the
# network. Reuses aur-sync.sh unmodified for the AUR/custom half --
# it stays the only thing that builds/installs vendored packages
# (decision #3) -- by redirecting pacman's own CacheDir rather than
# teaching aur-sync.sh a new flag.
#
# Usage: build-package-cache.sh REPO_DIR OUTPUT_DIR
#   REPO_DIR    an existing checkout (this script's own repo root works)
#   OUTPUT_DIR  where the repo (package files + .db) ends up; created if
#               missing. Meant to be copied into the ISO's airootfs
#               wholesale by build-iso.sh afterward.
#
# Must run as root (pacman -Sy/-Sw, editing /etc/pacman.conf, and
# aur-sync.sh itself all require it; aur-sync.sh drops to its own
# unprivileged sobarch-build user internally for the actual makepkg
# step, same as it does for a real install).

set -euo pipefail
shopt -s inherit_errexit

if (($# != 2)); then
    echo "usage: $0 REPO_DIR OUTPUT_DIR" >&2
    exit 1
fi

REPO_DIR="$(cd "$1" && pwd)"
OUTPUT_DIR="$2"
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"

# Conservative estimate, not a measured figure: GitHub's per-release-asset
# limit has long been ~2GiB, and package files (already zstd-compressed)
# gain little from squashfs's own compression on top, so budgeting the
# cache directory's raw size as a stand-in for its contribution to the
# final ISO is a reasonable approximation without a full trial mkarchiso
# run. BUDGET_BYTES leaves headroom for the releng+sobarch base system
# itself (kernel, desktop, installer/ checkout) on top of the cache.
# Recalibrate both numbers against a real build's actual output size and
# GitHub's current documented limit once one exists.
BUDGET_BYTES=$((1400 * 1024 * 1024))

echo "build-package-cache: redirecting pacman CacheDir to $OUTPUT_DIR"
sed -i "/^\[options\]/a CacheDir = $OUTPUT_DIR" /etc/pacman.conf

echo "build-package-cache: syncing package databases"
pacman -Sy

echo "build-package-cache: downloading official packages"
mapfile -t official < <(python3 "$(dirname "$0")/list-packages.py" --official)
pacman -Sw --noconfirm --needed "${official[@]}"

echo "build-package-cache: building/installing vendored AUR+custom packages"
mapfile -t aur_pkgs < <(python3 "$(dirname "$0")/list-packages.py" --aur)
"$REPO_DIR/scripts/aur-sync/aur-sync.sh" --local "$REPO_DIR" "${aur_pkgs[@]}"

# Only actual package files matter for the repo/budget below; pacman's
# CacheDir also holds sync-db copies for some setups, which repo-add has
# no use for.
find "$OUTPUT_DIR" -maxdepth 1 -type f ! -name '*.pkg.tar.*' -delete

total_size() {
    find "$OUTPUT_DIR" -maxdepth 1 -name '*.pkg.tar.*' -printf '%s\n' | awk '{s+=$1} END{print s+0}'
}

size="$(total_size)"
if ((size > BUDGET_BYTES)); then
    echo "build-package-cache: cache is ${size} bytes, over budget (${BUDGET_BYTES}); pruning largest packages"
    while ((size > BUDGET_BYTES)); do
        largest="$(du -b "$OUTPUT_DIR"/*.pkg.tar.* | sort -rn | head -1 | cut -f2)"
        [[ -n "$largest" ]] || break
        echo "build-package-cache: dropping $(basename "$largest") from the cache (still resolvable live, over network)"
        rm -f "$largest"
        size="$(total_size)"
    done
fi

echo "build-package-cache: final cache size $((size / 1024 / 1024)) MiB"

echo "build-package-cache: generating repo database"
repo-add "$OUTPUT_DIR/sobarch-cache.db.tar.gz" "$OUTPUT_DIR"/*.pkg.tar.*

echo "build-package-cache: done ($OUTPUT_DIR)"
