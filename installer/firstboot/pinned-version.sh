#!/usr/bin/env bash
# Sourced, not run. Compares installed vendored packages (packages/custom/)
# against the .SRCINFO pinned on the current channel's branch.

source /usr/local/lib/sobarch/channel.sh

# Prints the pinned [epoch:]pkgver-pkgrel, or returns 1 if it can't be read.
pinned_version() {
    local pkg="$1" srcinfo epoch pkgver pkgrel
    srcinfo="$(curl -fsSL "https://raw.githubusercontent.com/Dwarf1er/sobarch/$(sobarch_branch)/packages/custom/$pkg/.SRCINFO" 2>/dev/null)" || return 1
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

# Succeeds only if PKG is installed and the pinned version is newer. Any
# uncertainty counts as "not pending" so callers never prompt on a guess.
vendored_update_pending() {
    local pkg="$1" installed pinned
    installed="$(pacman -Q "$pkg" 2>/dev/null | awk '{print $2}')" || true
    [[ -n "$installed" ]] || return 1
    pinned="$(pinned_version "$pkg")" || return 1
    (( $(vercmp "$pinned" "$installed") > 0 ))
}
