#!/usr/bin/env bash
# Validates packages/custom/*/:
#   - fails if the committed .SRCINFO is stale (aur-sync.sh trusts it for
#     the pinned version)
#   - with BASE_REF set, fails if a package's payload changed without a
#     pkgver/pkgrel bump; without HEAD_REF it diffs against the working tree
#
# --fix bumps the version (pkgver=today, or pkgrel+1 if already today) and
# regenerates .SRCINFO, staging both. makepkg refuses to run as root.

set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

fix=false
[[ "${1:-}" == "--fix" ]] && fix=true

changed_files=()
if [[ -n "${BASE_REF:-}" ]]; then
    if [[ -n "${HEAD_REF:-}" ]]; then
        mapfile -t changed_files < <(git diff --name-only "$BASE_REF" "$HEAD_REF" 2>/dev/null)
    else
        mapfile -t changed_files < <(git diff --name-only "$BASE_REF" 2>/dev/null)
    fi
fi

pkgver_at() {
    # Prints "pkgver pkgrel" at <ref>, or nothing if the file is absent.
    local ref="$1" path="$2"
    if [[ "$ref" == "WORKTREE" ]]; then
        [[ -f "$path" ]] || return 0
        grep -oP '^pkgver=\K.*' "$path"
        grep -oP '^pkgrel=\K.*' "$path"
    else
        git show "${ref}:${path}" 2>/dev/null | grep -oP '^pkgver=\K.*'
        git show "${ref}:${path}" 2>/dev/null | grep -oP '^pkgrel=\K.*'
    fi
}

path_changed_under() {
    local prefix="$1" f
    for f in "${changed_files[@]:-}"; do
        [[ "$f" == "$prefix" || "$f" == "$prefix"/* ]] && return 0
    done
    return 1
}

mismatches=()
for dir in packages/custom/*/; do
    [[ -d "$dir" ]] || continue
    name="$(basename "$dir")"
    pkgbuild="${dir%/}/PKGBUILD"
    committed="${dir%/}/.SRCINFO"

    if ((${#changed_files[@]})); then
        # Payload paths are the PKGBUILD's $startdir/../../../<path> references,
        # matched as files unless followed by a '$' or ending in /. (directories).
        # The extra captured character is there to detect that trailing '$'.
        extra_paths=()
        while IFS= read -r raw; do
            [[ -n "$raw" ]] || continue
            nextchar="${raw: -1}"
            matched="${raw%?}"
            rel="${matched#\$startdir/../../../}"
            if [[ "$nextchar" == '$' || "$rel" == */. || "$rel" == */ ]]; then
                rel="${rel%/.}"
                rel="${rel%/}"
            fi
            extra_paths+=("$rel")
        done < <(grep -oE '\$startdir/\.\./\.\./\.\./[A-Za-z0-9_./-]+.' "$pkgbuild" | sort -u)

        payload_changed=false
        for f in "${changed_files[@]}"; do
            if [[ "$f" == "$dir"* && "$f" != "$pkgbuild" && "$f" != "$committed" ]]; then
                payload_changed=true
                break
            fi
        done
        if ! $payload_changed; then
            for p in "${extra_paths[@]:-}"; do
                [[ -n "$p" ]] || continue
                if path_changed_under "$p"; then
                    payload_changed=true
                    break
                fi
            done
        fi

        if $payload_changed; then
            read -r base_ver base_rel < <(pkgver_at "$BASE_REF" "$pkgbuild" | tr '\n' ' ')
            read -r head_ver head_rel < <(pkgver_at "WORKTREE" "$pkgbuild" | tr '\n' ' ')
            if [[ -n "$base_ver" && "$base_ver $base_rel" == "$head_ver $head_rel" ]]; then
                if $fix; then
                    today="$(date +%Y%m%d)"
                    if [[ "$head_ver" == "$today" ]]; then
                        new_ver="$head_ver"
                        new_rel=$((head_rel + 1))
                    else
                        new_ver="$today"
                        new_rel=1
                    fi
                    sed -i "s/^pkgver=.*/pkgver=$new_ver/" "$pkgbuild"
                    sed -i "s/^pkgrel=.*/pkgrel=$new_rel/" "$pkgbuild"
                    echo "== $name: payload changed (${extra_paths[*]:-$dir}); bumped $head_ver-$head_rel -> $new_ver-$new_rel =="
                    git add "$pkgbuild"
                else
                    echo "== $name: payload changed (${extra_paths[*]:-$dir}) but pkgver/pkgrel didn't =="
                    mismatches+=("$name (payload changed without a version bump)")
                fi
            fi
        fi
    fi

    # Runs last so it picks up any version bump made above.
    generated="$(mktemp)"
    if ! (cd "$dir" && makepkg --printsrcinfo) > "$generated" 2>/dev/null; then
        echo "== $name: makepkg --printsrcinfo failed =="
        mismatches+=("$name (printsrcinfo failed)")
        rm -f "$generated"
        continue
    fi

    if [[ ! -f "$committed" ]] || ! diff -u "$committed" "$generated" > /dev/null; then
        if $fix; then
            cp "$generated" "$committed"
            echo "== $name: regenerated .SRCINFO =="
            git add "$committed"
        elif [[ ! -f "$committed" ]]; then
            echo "== $name: missing .SRCINFO =="
            mismatches+=("$name (missing .SRCINFO)")
        else
            diff -u "$committed" "$generated"
            echo "== $name: .SRCINFO is stale, regenerate with 'makepkg --printsrcinfo > .SRCINFO' =="
            mismatches+=("$name (.SRCINFO stale)")
        fi
    fi
    rm -f "$generated"
done

if ((${#mismatches[@]})); then
    echo "validate-custom-pkgbuilds: failing on: ${mismatches[*]}" >&2
    exit 1
fi
