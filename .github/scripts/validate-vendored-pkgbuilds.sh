#!/usr/bin/env bash
# Validates every packages/aur/*/ directory (AUR-sourced content only --
# packages/custom/ is this project's own PKGBUILD, out of scope here):
#
#   - Regenerates .SRCINFO via makepkg and fails if it doesn't match
#     what's committed. The concrete failure mode this guards against:
#     a hand-edited PKGBUILD whose .SRCINFO was never regenerated --
#     aur-sync.sh trusts .SRCINFO as its sole source of truth for a
#     package's pinned version (see that script's pinned_version()),
#     so a stale one means it silently compares against the wrong
#     version.
#   - Runs namcap against the PKGBUILD. Advisory only, never fails the
#     run: namcap findings need a human's judgment (e.g. this repo
#     deliberately sets options=(!debug) on some packages, which
#     namcap flags), same treatment checks.yml gives ks-aur-scanner.
#
# Must run as a non-root user: makepkg refuses outright to run as
# root.

set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

mismatches=()
for dir in packages/aur/*/; do
    [[ -d "$dir" ]] || continue
    name="$(basename "$dir")"
    committed="$dir/.SRCINFO"
    generated="$(mktemp)"

    if ! (cd "$dir" && makepkg --printsrcinfo) > "$generated" 2>/dev/null; then
        echo "== $name: makepkg --printsrcinfo failed =="
        mismatches+=("$name (printsrcinfo failed)")
        rm -f "$generated"
        continue
    fi

    if [[ ! -f "$committed" ]]; then
        echo "== $name: missing .SRCINFO =="
        mismatches+=("$name (missing .SRCINFO)")
    elif ! diff -u "$committed" "$generated"; then
        echo "== $name: .SRCINFO is stale, regenerate with 'makepkg --printsrcinfo > .SRCINFO' =="
        mismatches+=("$name (.SRCINFO stale)")
    fi
    rm -f "$generated"

    echo "== $name: namcap =="
    namcap "$dir/PKGBUILD" || true
done

if ((${#mismatches[@]})); then
    echo "validate-vendored-pkgbuilds: failing on: ${mismatches[*]}" >&2
    exit 1
fi
