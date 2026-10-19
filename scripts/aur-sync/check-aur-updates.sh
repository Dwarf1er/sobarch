#!/usr/bin/env bash
# Prints "name pinned upstream" for each packages/aur/ package behind the
# AUR. -git packages have no meaningful version, so they are compared by
# content instead and printed as "name content-changed".

set -euo pipefail
shopt -s inherit_errexit

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

pinned_version() {
    local srcinfo="$1/.SRCINFO" epoch pkgver pkgrel
    epoch="$(awk -F' = ' '/^[[:space:]]*epoch = /{print $2; exit}' "$srcinfo")"
    pkgver="$(awk -F' = ' '/^[[:space:]]*pkgver = /{print $2; exit}' "$srcinfo")"
    pkgrel="$(awk -F' = ' '/^[[:space:]]*pkgrel = /{print $2; exit}' "$srcinfo")"
    if [[ -n "$epoch" ]]; then
        echo "${epoch}:${pkgver}-${pkgrel}"
    else
        echo "${pkgver}-${pkgrel}"
    fi
}

names=()
git_names=()
for dir in packages/aur/*/; do
    name="$(basename "$dir")"
    if [[ "$name" == *-git ]]; then
        git_names+=("$name")
    else
        names+=("$name")
    fi
done

query=""
for name in "${names[@]}"; do
    query+="arg[]=${name}&"
done

response="$(curl -fsSL "https://aur.archlinux.org/rpc/v5/info?${query%&}")"

for name in "${names[@]}"; do
    pinned="$(pinned_version "packages/aur/$name")"
    upstream="$(jq -r --arg n "$name" '.results[] | select(.Name == $n) | .Version' <<<"$response")"
    if [[ -z "$upstream" ]]; then
        echo "check-aur-updates: $name not found on AUR (skipping)" >&2
        continue
    fi
    if (( $(vercmp "$upstream" "$pinned") > 0 )); then
        echo "$name $pinned $upstream"
    fi
done

# Copies a package dir minus .SRCINFO and the pkgver/pkgrel lines, leaving
# only the maintainer's content.
normalized_copy() {
    mkdir -p "$2"
    find "$1" -mindepth 1 -maxdepth 1 -not -name '.git' -not -name '.SRCINFO' -exec cp -a {} "$2/" \;
    [[ -f "$2/PKGBUILD" ]] && sed -i -E '/^(pkgver|pkgrel)=/d' "$2/PKGBUILD"
    return 0
}

if ((${#git_names[@]})); then
    work="$(mktemp -d)"
    trap 'rm -rf "$work"' EXIT
    for name in "${git_names[@]}"; do
        if ! git clone -q --depth 1 "https://aur.archlinux.org/${name}.git" "$work/$name.upstream" 2>/dev/null; then
            echo "check-aur-updates: could not clone $name from AUR (skipping)" >&2
            continue
        fi
        normalized_copy "$work/$name.upstream" "$work/$name.a"
        normalized_copy "packages/aur/$name" "$work/$name.b"
        if ! diff -rq "$work/$name.a" "$work/$name.b" >/dev/null; then
            echo "$name content-changed"
        fi
    done
fi
