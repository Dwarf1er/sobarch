#!/usr/bin/env bash
# Read-only: compares each vendored packages/aur/*/.SRCINFO pinned
# version against the AUR's current released version (RPC v5 info, one
# batched request), never touches the working tree. Prints one line per
# package that's behind, "name pinned upstream", to stdout. Used by
# .github/workflows/aur.yml to pick which packages need
# apply-aur-update.sh.
#
# -git packages can't use the version comparison: their pkgver()
# recomputes from a live clone at build time (see aur-sync.sh's own
# pinned_version() note), so AUR's Version field is just whatever the
# maintainer last set by hand, not a real signal that upstream moved.
# What can still matter is the maintainer changing the PKGBUILD itself
# (new dependency, source URL, build fix), so each is checked by
# content instead: a shallow clone of its AUR repo, compared against
# the vendored copy with pkgver/pkgrel lines and .SRCINFO ignored.
# Prints "name content-changed" for one that differs.

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

# Copies a package dir to $2 with the lines a VCS package's own
# bookkeeping rewrites (pkgver/pkgrel) and the regenerated .SRCINFO
# removed, so what's left is only the maintainer's actual content.
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
