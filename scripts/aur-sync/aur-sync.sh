#!/usr/bin/env bash
# Builds and installs vendored packages/aur/ and packages/custom/
# packages locally, no AUR helper, no hosted binary repository (decision
# 3). Two modes, same underlying logic either way:
#
#   aur-sync.sh [--local DIR] PKG...
#       Explicit mode: build/install exactly the named packages,
#       whether or not they're currently installed. Used for a
#       package's first-ever install (base-required packages during the
#       install session itself, profile packages at first boot).
#
#   aur-sync.sh [--local DIR]
#       Sync mode (no package names): only touches package names that
#       are ALREADY installed. This is what the pacman hook runs on
#       every `Operation = Upgrade` transaction; it must never
#       force-install a vendored package onto a system that never
#       asked for it (e.g. a profile package the user didn't select).
#
# Either mode: --local DIR points at an existing checkout instead of
# fetching one (used by the install-session call, which already has one
# on disk); otherwise the current repo state is fetched fresh via the
# same curl+tar mechanism bootstrap.sh uses, so the ongoing/first-boot
# calls always see the actual current packages/aur/+packages/custom/
# state, never a stale leftover checkout.
#
# Hard scope limit: a package name is only ever acted on if it's
# actually present under DIR's packages/aur/ or packages/custom/. This
# script must never gain license to build arbitrary AUR packages.

set -euo pipefail
shopt -s inherit_errexit

REPO="Dwarf1er/sobarch"
BRANCH="master"
ARCHIVE_URL="https://github.com/${REPO}/archive/refs/heads/${BRANCH}.tar.gz"

BUILD_USER="sobarch-build"
BUILD_ROOT="/var/tmp/sobarch-aur-sync-build"
LOG_FILE="/var/log/sobarch/aur-sync.log"

mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "aur-sync: run started $(date -Iseconds)"

repo_dir=""
if [[ "${1:-}" == "--local" ]]; then
    repo_dir="$2"
    shift 2
fi
explicit_packages=("$@")

cleanup_paths=("$BUILD_ROOT")
# makepkg refuses outright to run as root (no override flag), and this
# script itself needs to run as root (pacman -U, useradd); a dedicated,
# no-login system account isolates the actual build step instead of
# reusing whichever human account happens to exist at call time (the
# install session's new user, or nobody at all when run from the
# pacman hook on an already-running system).
ensure_build_user() {
    id -u "$BUILD_USER" >/dev/null 2>&1 && return 0
    echo "aur-sync: creating build user $BUILD_USER..."
    useradd --system --create-home --home-dir "/var/lib/$BUILD_USER" \
        --shell /usr/bin/nologin "$BUILD_USER"
}

fetch_repo() {
    local dir
    dir="$(mktemp -d /var/tmp/sobarch-aur-sync-repo.XXXXXX)"
    # stderr, not stdout: this function's stdout is captured whole as
    # its return value (repo_dir="$(fetch_repo)"), so any status output
    # mixed into stdout here would corrupt that path.
    echo "aur-sync: fetching current repo state from ${REPO}@${BRANCH}..." >&2
    curl -fsSL "$ARCHIVE_URL" | tar -xz -C "$dir" --strip-components=1
    echo "$dir"
}

trap 'rm -rf "${cleanup_paths[@]}"' EXIT

if [[ -z "$repo_dir" ]]; then
    # Called via command substitution (its own subshell), so it can't
    # append to this shell's cleanup_paths itself; done here instead,
    # right after the path comes back, so the fetched checkout is still
    # cleaned up at exit.
    repo_dir="$(fetch_repo)"
    cleanup_paths+=("$repo_dir")
elif [[ ! -d "$repo_dir" ]]; then
    echo "aur-sync: --local $repo_dir does not exist" >&2
    exit 1
fi

# The full set this script is ever allowed to touch: package name ->
# its vendored source directory. Built once, up front, so the
# scope-limit check below is a simple lookup rather than a filesystem
# probe repeated per package.
declare -A pkg_dir
for group in aur custom; do
    [[ -d "$repo_dir/packages/$group" ]] || continue
    for dir in "$repo_dir/packages/$group"/*/; do
        [[ -d "$dir" ]] || continue
        pkg_dir["$(basename "$dir")"]="${dir%/}"
    done
done

targets=()
scope_failures=()
if ((${#explicit_packages[@]})); then
    for name in "${explicit_packages[@]}"; do
        if [[ -n "${pkg_dir[$name]:-}" ]]; then
            targets+=("$name")
        else
            scope_failures+=("$name")
        fi
    done
    if ((${#scope_failures[@]})); then
        echo "aur-sync: refusing to build unvendored package(s): ${scope_failures[*]}" >&2
    fi
else
    for name in "${!pkg_dir[@]}"; do
        pacman -Q "$name" >/dev/null 2>&1 && targets+=("$name")
    done
fi

# Version pinned in the vendored .SRCINFO, as pacman's own `vercmp`
# expects it (epoch:pkgver-pkgrel, epoch omitted when absent). Reading
# .SRCINFO rather than PKGBUILD itself: it's the same plain,
# machine-readable snapshot `makepkg --printsrcinfo` produces, so no
# bash parsing/sourcing of a vendored PKGBUILD is needed just to check
# a version.
#
# Note on -git packages (quickemu-git): their PKGBUILD recomputes
# pkgver() from a live git clone at build time, so the version actually
# installed will usually be newer than whatever was pinned in .SRCINFO
# at vendor time. This means version comparison alone won't reliably
# detect "upstream moved" for a -git package once it's already
# installed; it still builds and installs correctly on first install
# (makepkg always builds the current pkgver() regardless of what this
# comparison said). Revisit if that turns out to matter in practice.
pinned_version() {
    local srcinfo="$1/.SRCINFO" epoch pkgver pkgrel
    if [[ ! -f "$srcinfo" ]]; then
        echo "aur-sync: $srcinfo does not exist" >&2
        return 1
    fi
    epoch="$(awk -F' = ' '/^[[:space:]]*epoch = /{print $2; exit}' "$srcinfo")"
    pkgver="$(awk -F' = ' '/^[[:space:]]*pkgver = /{print $2; exit}' "$srcinfo")"
    pkgrel="$(awk -F' = ' '/^[[:space:]]*pkgrel = /{print $2; exit}' "$srcinfo")"
    if [[ -z "$pkgver" || -z "$pkgrel" ]]; then
        echo "aur-sync: $srcinfo has no pkgver/pkgrel" >&2
        return 1
    fi
    if [[ -n "$epoch" ]]; then
        echo "${epoch}:${pkgver}-${pkgrel}"
    else
        echo "${pkgver}-${pkgrel}"
    fi
}

installed_version() {
    # Not being installed at all is an expected, normal outcome here
    # (not an error): `|| true` keeps that from tripping pipefail under
    # inherit_errexit, so the caller just sees an empty version.
    pacman -Q "$1" 2>/dev/null | awk '{print $2}' || true
}

# depends/makedepends declared in .SRCINFO, stripped of version
# constraints (e.g. "fuse2>=2.9.9" -> "fuse2") so they're plain names
# pacman -S accepts. No arch-specific depends_x86_64-style variants are
# handled: none of the currently vendored packages use them, and this
# is meant to stay a thin reader of what's actually there, not a full
# .SRCINFO parser.
build_deps() {
    awk -F' = ' '/^[[:space:]]*(depends|makedepends) = /{print $2}' "$1/.SRCINFO" | sed -E 's/[<>=].*//'
}

# makepkg verifies a source's PGP signature (when validpgpkeys is set,
# e.g. wlogout) against gpg's own keyring, never fetching a missing key
# itself; imported here, into the build user's own keyring, before
# makepkg runs, rather than relying on it happening implicitly (a fresh
# account's keyring starts empty, and gpg has no keyserver configured
# by default to fall back on).
import_pgp_keys() {
    local src="$1" key
    while IFS= read -r key; do
        [[ -n "$key" ]] || continue
        runuser -u "$BUILD_USER" -- gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys "$key" || return 1
    done < <(awk -F' = ' '/^[[:space:]]*validpgpkeys = /{print $2}' "$src/.SRCINFO")
}

# base-devel (a single meta-package on recent Arch, not a group) is the
# full set of tools any PKGBUILD is entitled to assume is already
# present without declaring it in makedepends, per Arch's own
# packaging convention (a compiler for a real build() step, e.g.
# wlogout's meson build; debugedit for makepkg's own default
# debug-package generation, which sobarch-skel's PKGBUILD works around
# with !debug precisely because base-devel isn't part of this minimal
# base install otherwise). Installed once, up front, rather than
# patching every vendored PKGBUILD's makedepends/options to spell out
# what it assumes, which would pollute Phase 11's future upstream-diff
# checks with a spurious, permanent local difference.
ensure_makepkg_prereqs() {
    pacman -S --needed --noconfirm base-devel
}

failures=()
first_install=true

if ((${#targets[@]})); then
    ensure_build_user
    ensure_makepkg_prereqs
    mkdir -p "$BUILD_ROOT"
fi

for name in $(printf '%s\n' "${targets[@]}" | sort); do
    src="${pkg_dir[$name]}"
    if ! pinned="$(pinned_version "$src")"; then
        failures+=("$name (unreadable .SRCINFO)")
        continue
    fi
    installed="$(installed_version "$name")"

    if [[ -n "$installed" ]] && (( $(vercmp "$pinned" "$installed") <= 0 )); then
        echo "aur-sync: $name is up to date ($installed)."
        continue
    fi

    echo "aur-sync: building $name (${installed:-not installed} -> $pinned)..."

    # Resolved as root, here, rather than via `makepkg --syncdeps`:
    # that flag has makepkg itself invoke pacman, which would mean
    # granting the unprivileged build user passwordless pacman/sudo
    # rights just to build a package - a real privilege-escalation
    # surface this project has no reason to open, since decision 3
    # already rejects an AUR helper for the same class of concern.
    mapfile -t deps < <(build_deps "$src")
    if ((${#deps[@]})) && ! pacman -S --needed --noconfirm "${deps[@]}"; then
        echo "aur-sync: $name failed to install dependencies (${deps[*]})" >&2
        failures+=("$name (dependency install failed)")
        continue
    fi

    if ! import_pgp_keys "$src"; then
        echo "aur-sync: $name failed to import required PGP key(s)" >&2
        failures+=("$name (PGP key import failed)")
        continue
    fi

    build_dir="$BUILD_ROOT/$name"
    rm -rf "$build_dir"
    cp -a "$src" "$build_dir"
    chown -R "$BUILD_USER:$BUILD_USER" "$build_dir"

    if ! runuser -u "$BUILD_USER" -- bash -c "cd '$build_dir' && makepkg --noconfirm --needed --clean"; then
        echo "aur-sync: $name failed to build" >&2
        failures+=("$name (makepkg failed)")
        continue
    fi

    pkgfiles=("$build_dir"/*.pkg.tar.*)

    # snap-pac creates a fresh Snapper snapshot pair per pacman
    # transaction with no built-in debounce; skip it for every install
    # in this run after the first to avoid snapshot spam from one
    # aur-sync pass touching several packages back to back.
    if $first_install; then
        install_result=0
        pacman -U --noconfirm "${pkgfiles[@]}" || install_result=$?
    else
        install_result=0
        SNAP_PAC_SKIP=1 pacman -U --noconfirm "${pkgfiles[@]}" || install_result=$?
    fi

    rm -rf "$build_dir"

    if ((install_result != 0)); then
        echo "aur-sync: $name failed to install" >&2
        failures+=("$name (pacman -U failed)")
        continue
    fi

    first_install=false
    echo "aur-sync: $name installed ($pinned)."
done

if ((${#scope_failures[@]} + ${#failures[@]})); then
    echo "aur-sync: run finished with failures." >&2
    exit 1
fi

echo "aur-sync: run finished, nothing left to do."
