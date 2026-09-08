#!/usr/bin/env bash
# Validates every packages/custom/*/ directory (this project's own
# PKGBUILDs -- packages/aur/ is out of scope here, see
# validate-vendored-pkgbuilds.sh):
#
#   - Regenerates .SRCINFO via makepkg and fails if it doesn't match
#     what's committed. Same failure mode as the AUR check: aur-sync.sh
#     trusts .SRCINFO as its sole source of truth for a package's
#     pinned version.
#   - Payload-without-a-version-bump check: several of these packages
#     package content from outside their own directory (e.g.
#     sobarch-skel's package() copies skel/), so editing that
#     content is easy to do without remembering to also bump the
#     package's pkgver/pkgrel. Each package's real payload paths are
#     derived directly from its own PKGBUILD (grepping for
#     $startdir/../../../<path> references), not a separately
#     maintained mapping that could itself drift. If any payload path
#     changed between BASE_REF and HEAD_REF but the PKGBUILD's
#     pkgver/pkgrel didn't, that's a real bug: this is exactly what
#     happened for real with sobarch-skel and the ble.sh commit.
#     Skipped entirely when BASE_REF/HEAD_REF aren't set (e.g. a
#     workflow_dispatch run with no PR base to diff against).
#   - Runs namcap against the PKGBUILD. Advisory only, never fails the
#     run, same treatment the AUR check gives it.
#
# Must run as a non-root user: makepkg refuses outright to run as
# root.

set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

changed_files=()
if [[ -n "${BASE_REF:-}" && -n "${HEAD_REF:-}" ]]; then
    mapfile -t changed_files < <(git diff --name-only "$BASE_REF" "$HEAD_REF" 2>/dev/null)
fi

pkgver_at() {
    # pkgver_at <ref> <pkgbuild-path> -- prints "pkgver pkgrel", or
    # nothing if the file doesn't exist at that ref.
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
    # path_changed_under <path> -- true if any changed file is exactly
    # <path>, or lives under it when <path> is a directory.
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
    namcap "$pkgbuild" || true

    if ((${#changed_files[@]})); then
        # Derive this package's external payload paths straight from
        # its own PKGBUILD: any $startdir/../../../<path> reference.
        # Matched at file granularity by default (e.g.
        # .../aur-sync/aur-sync.sh watches only that file, not every
        # other file that happens to live in scripts/aur-sync/) --
        # only treated as a directory when the reference is genuinely
        # directory-shaped: a trailing shell variable (a for-loop's
        # .../firstboot/$script, whatever it expands to) or the
        # trailing-/. copy-contents idiom (cp -a .../skel/.).
        # One extra trailing character is captured past the matched
        # path so a '$' right after it can be detected.
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
            # The package's own dir counts as payload except for the
            # version-metadata files themselves.
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
                echo "== $name: payload changed (${extra_paths[*]:-$dir}) but pkgver/pkgrel didn't =="
                mismatches+=("$name (payload changed without a version bump)")
            fi
        fi
    fi
done

if ((${#mismatches[@]})); then
    echo "validate-custom-pkgbuilds: failing on: ${mismatches[*]}" >&2
    exit 1
fi
