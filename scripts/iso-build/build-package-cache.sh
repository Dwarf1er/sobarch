#!/usr/bin/env bash
# Builds a local pacman repo carrying the base-required packages (see
# list-packages.py -- official + the AUR/custom packages
# install_runner.py already builds synchronously before first boot), so
# a real install resolves them from the ISO's own airootfs instead of
# the network. Optional software profiles are out of scope (decision
# #20's addendum: an every-profile cache measured 3.25GB against
# GitHub's real 2GiB release-asset limit) and still install over the
# network at first boot, same as any other install path.
#
# Reuses aur-sync.sh unmodified for the AUR/custom half --
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

# Calibrated against a real measured build (2026-09-22), not a guess:
# that run's base-required cache was 705MiB (under the old 1400MiB
# budget, so it pruned nothing) and the final ISO came out to 2249MiB --
# 201MiB over GitHub's real 2GiB (2048MiB) release-asset limit. That
# means the fixed overhead alone (releng's base live system, kernel,
# this repo's own checkout) is ~1544MiB (2249 - 705), the dominant cost,
# not the cache. Targeting a total ISO size of ~1950MiB (~100MiB margin
# for month-to-month drift in kernel/base-package sizes) leaves about
# 400MiB of actual cache budget. See decision #20's addendum for the
# full numbers and the (unexplored) alternative of a leaner archiso base
# profile instead of cutting the cache this much.
BUDGET_BYTES=$((400 * 1024 * 1024))

echo "build-package-cache: redirecting pacman CacheDir to $OUTPUT_DIR"
sed -i "/^\[options\]/a CacheDir = $OUTPUT_DIR" /etc/pacman.conf

# base.json enables multilib for the real *target* itself via
# mirror_config's optional_repositories (archinstall's own
# pacman_conf.enable()), but that has no effect on this container's own
# pacman -- steam/lib32-mesa and anything else multilib-only need it
# enabled here too. Appended fresh rather than uncommenting whatever the
# image's stock pacman.conf happens to ship (that turned out to vary in
# ways not worth chasing); safe because this container is a fresh
# instance every run, so there's no accumulating-duplicate-section risk
# to guard against.
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

# Pacman's CacheDir also holds the detached .sig files it downloads
# alongside signature-verified packages -- these match the *.pkg.tar.*
# glob too (named <pkg>.pkg.tar.zst.sig), so they must be removed
# explicitly, first, before the general cleanup below filters by that
# same glob. repo-add refuses to write the database at all if it's
# handed even one non-package file, so leaving these in silently broke
# every run, not just that one package.
find "$OUTPUT_DIR" -maxdepth 1 -type f -name '*.sig' -delete

# Only actual package files matter for the repo/budget below; pacman's
# CacheDir also holds sync-db copies for some setups, which repo-add has
# no use for.
find "$OUTPUT_DIR" -maxdepth 1 -type f ! -name '*.pkg.tar.*' -delete

total_size() {
    find "$OUTPUT_DIR" -maxdepth 1 -name '*.pkg.tar.*' -printf '%s\n' | awk '{s+=$1} END{print s+0}'
}

# Finds the single largest .pkg.tar.* file without piping through
# `sort | head` -- under `set -o pipefail`, `head -1` closing the pipe
# early sends SIGPIPE back up through `sort`, which pipefail then
# treats as a real failure (exit 141) and aborts the whole script. A
# plain bash loop over every file never closes a pipe early, so there's
# nothing for pipefail to trip on.
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
