#!/usr/bin/env bash
# Validates packages/aur/*/ (or only the named packages):
#   - fails if the committed .SRCINFO is stale (aur-sync.sh trusts it for
#     the pinned version)
#   - runs namcap, advisory only
# makepkg refuses to run as root.

set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

if (($#)); then
    dirs=("${@/#/packages/aur/}")
    dirs=("${dirs[@]/%//}")
else
    dirs=(packages/aur/*/)
fi

mismatches=()
for dir in "${dirs[@]}"; do
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
