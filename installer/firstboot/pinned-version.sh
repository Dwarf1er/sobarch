#!/usr/bin/env bash
# Sourced by update-system-menu.sh and sobarch-update-check.sh, never
# run directly: the one place that decides whether an installed
# vendored sobarch package (packages/custom/) is behind the version
# pinned on GitHub's master branch. Reads the committed .SRCINFO, same
# source aur-sync.sh's own version comparison uses, one small file per
# package instead of the whole repo tarball. Needs no root.

# Prints the pinned [epoch:]pkgver-pkgrel of a packages/custom/ package,
# or returns 1 (printing nothing) if it can't be determined (offline,
# GitHub hiccup, malformed .SRCINFO).
pinned_version() {
    local pkg="$1" srcinfo epoch pkgver pkgrel
    srcinfo="$(curl -fsSL "https://raw.githubusercontent.com/Dwarf1er/sobarch/master/packages/custom/$pkg/.SRCINFO" 2>/dev/null)" || return 1
    epoch="$(awk -F' = ' '/^[[:space:]]*epoch = /{print $2; exit}' <<<"$srcinfo")"
    pkgver="$(awk -F' = ' '/^[[:space:]]*pkgver = /{print $2; exit}' <<<"$srcinfo")"
    pkgrel="$(awk -F' = ' '/^[[:space:]]*pkgrel = /{print $2; exit}' <<<"$srcinfo")"
    [[ -n "$pkgver" && -n "$pkgrel" ]] || return 1
    if [[ -n "$epoch" ]]; then
        echo "${epoch}:${pkgver}-${pkgrel}"
    else
        echo "${pkgver}-${pkgrel}"
    fi
}

# Succeeds only if PKG is installed AND the pinned version is newer. A
# package that isn't installed, or whose pinned version can't be
# determined, is "not pending": callers use this to decide whether to
# ask for a password or show a notification, and both are wrong to do
# on a guess.
vendored_update_pending() {
    local pkg="$1" installed pinned
    installed="$(pacman -Q "$pkg" 2>/dev/null | awk '{print $2}')" || true
    [[ -n "$installed" ]] || return 1
    pinned="$(pinned_version "$pkg")" || return 1
    (( $(vercmp "$pinned" "$installed") > 0 ))
}
