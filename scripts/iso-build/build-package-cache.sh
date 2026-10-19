#!/usr/bin/env bash
# Builds a local pacman repo of the base-required packages for the ISO,
# so installs don't fetch them over the network. Vendored packages are
# built by aur-sync.sh with pacman's CacheDir redirected to OUTPUT_DIR.
#
# Usage: build-package-cache.sh REPO_DIR OUTPUT_DIR
#
# Must run as root.

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

# The ISO's fixed overhead is ~1544MiB, so this keeps it under GitHub's
# 2GiB release-asset limit with some margin.
BUDGET_BYTES=$((400 * 1024 * 1024))

echo "build-package-cache: redirecting pacman CacheDir to $OUTPUT_DIR"
sed -i "/^\[options\]/a CacheDir = $OUTPUT_DIR" /etc/pacman.conf

# base.json's multilib setting only affects the target, not this container.
echo "build-package-cache: enabling multilib"
cat >> /etc/pacman.conf <<'PACMAN_CONF'

[multilib]
Include = /etc/pacman.d/mirrorlist
PACMAN_CONF

echo "build-package-cache: syncing package databases"
pacman -Sy

echo "build-package-cache: downloading official packages"
mapfile -t official < <(python3 "$(dirname "$0")/list-packages.py" --official)
pacman -Sw --noconfirm --needed "${official[@]}"

echo "build-package-cache: building/installing vendored AUR+custom packages"
mapfile -t aur_pkgs < <(python3 "$(dirname "$0")/list-packages.py" --aur)
"$REPO_DIR/scripts/aur-sync/aur-sync.sh" --local "$REPO_DIR" "${aur_pkgs[@]}"

# .sig files match the *.pkg.tar.* glob, and repo-add fails on any
# non-package file.
find "$OUTPUT_DIR" -maxdepth 1 -type f -name '*.sig' -delete

find "$OUTPUT_DIR" -maxdepth 1 -type f ! -name '*.pkg.tar.*' -delete

total_size() {
    find "$OUTPUT_DIR" -maxdepth 1 -name '*.pkg.tar.*' -printf '%s\n' | awk '{s+=$1} END{print s+0}'
}

# A loop instead of `sort | head`, whose SIGPIPE trips pipefail.
largest_pkg() {
    local f largest="" largest_size=-1 sz
    while IFS= read -r -d '' f; do
        sz="$(stat -c%s "$f")"
        if ((sz > largest_size)); then
            largest_size=$sz
            largest="$f"
        fi
    done < <(find "$OUTPUT_DIR" -maxdepth 1 -name '*.pkg.tar.*' -print0)
    printf '%s' "$largest"
}

size="$(total_size)"
echo "build-package-cache: raw cache size before any pruning: $((size / 1024 / 1024)) MiB"
if ((size > BUDGET_BYTES)); then
    echo "build-package-cache: cache is ${size} bytes, over budget (${BUDGET_BYTES}); pruning largest packages"
    while ((size > BUDGET_BYTES)); do
        largest="$(largest_pkg)"
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
