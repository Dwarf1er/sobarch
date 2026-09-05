#!/usr/bin/env bash
# Read-only: compares each vendored packages/aur/*/.SRCINFO pinned
# version against the AUR's current released version (RPC v5 info, one
# batched request), never touches the working tree. Prints one line per
# package that's behind, "name pinned upstream", to stdout. Used by
# .github/workflows/aur.yml to pick which packages need
# apply-aur-update.sh.
#
# -git packages are skipped: same reasoning as aur-sync.sh's own
# pinned_version() note (that script's pinned-version comparison is
# unreliable for a VCS package once installed, since its pkgver()
# recomputes from a live clone at build time; here it means AUR's
# Version field for one is just whatever the maintainer last set by
# hand, not a real signal that upstream moved). quickemu-git is
# currently the only vendored package this excludes.

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
for dir in packages/aur/*/; do
    name="$(basename "$dir")"
    [[ "$name" == *-git ]] && continue
    names+=("$name")
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
