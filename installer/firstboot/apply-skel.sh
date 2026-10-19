#!/usr/bin/env bash
# Deploys /usr/share/sobarch/skel/ into $HOME with a three-way diff3 merge
# against the last applied version. Runs as the target user, not root.
#
# The first run takes every file outright: useradd already seeded .bashrc
# from /etc/skel, and with no baseline diff3 would report it as a conflict.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/durable-replace.sh"

SKEL_SRC="/usr/share/sobarch/skel"
STATE_DIR="$HOME/.local/state/sobarch"
VERSION_FILE="$STATE_DIR/skel-version"
BASELINE_DIR="$STATE_DIR/skel-baseline"

if [[ ! -d "$SKEL_SRC" ]]; then
    echo "apply-skel: $SKEL_SRC does not exist (sobarch-skel is not installed); nothing to do." >&2
    exit 1
fi

new_version="$(pacman -Qi sobarch-skel 2>/dev/null | awk -F': ' '/^Version/ {print $2}')"
if [[ -z "$new_version" ]]; then
    echo "apply-skel: sobarch-skel is not a registered pacman package; nothing to do." >&2
    exit 1
fi

mkdir -p "$STATE_DIR"

first_run=true
[[ -f "$VERSION_FILE" ]] && first_run=false

empty_file="$(mktemp)"
merge_tmp="$(mktemp)"
trap 'rm -f "$empty_file" "$merge_tmp"' EXIT

conflicts=()
failures=()

# -a: diff3 refuses binary files (e.g. the wallpaper) without it.
while IFS= read -r -d '' new_file; do
    rel="${new_file#"$SKEL_SRC"/}"
    current_file="$HOME/$rel"
    baseline_file="$BASELINE_DIR/$rel"

    mode="$(stat -c%a "$new_file")"

    if $first_run; then
        durable_replace "$mode" "$new_file" "$current_file"
        durable_replace "$mode" "$new_file" "$baseline_file"
        continue
    fi

    current_input="$current_file"
    [[ -e "$current_input" ]] || current_input="$empty_file"
    baseline_input="$baseline_file"
    [[ -e "$baseline_input" ]] || baseline_input="$empty_file"

    rc=0
    diff3 -a -m "$current_input" "$baseline_input" "$new_file" > "$merge_tmp" || rc=$?
    case "$rc" in
        0)
            durable_replace "$mode" "$merge_tmp" "$current_file"
            durable_replace "$mode" "$new_file" "$baseline_file"
            ;;
        1)
            # Both sides changed: leave the user's file alone and write the
            # merge result as .sobarch-new. The baseline is not advanced so
            # the conflict keeps showing until it's resolved.
            durable_replace "$mode" "$merge_tmp" "$current_file.sobarch-new"
            conflicts+=("$rel")
            ;;
        *)
            # diff3 itself failed: skip this file, keep going.
            failures+=("$rel (diff3 exited $rc)")
            ;;
    esac
done < <(find "$SKEL_SRC" -type f -print0)

# GTK bookmarks need absolute file:// URIs, so they're generated per user.
# Seeded once on first run and left to the user afterwards.
if $first_run; then
    bookmarks_tmp="$(mktemp)"
    for d in Documents Downloads Music Pictures Videos; do
        printf 'file://%s/%s\n' "$HOME" "$d"
    done > "$bookmarks_tmp"
    mkdir -p "$HOME/.config/gtk-3.0"
    durable_replace 644 "$bookmarks_tmp" "$HOME/.config/gtk-3.0/bookmarks"
    rm -f "$bookmarks_tmp"
fi

if ((${#conflicts[@]})); then
    echo "apply-skel: ${#conflicts[@]} file(s) have local changes that conflict with the new defaults;" \
        "new versions were written alongside as .sobarch-new (Sobarch -> Review Conflicts to resolve):"
    printf '  %s\n' "${conflicts[@]}"
fi

if ((${#failures[@]})); then
# Never stamp VERSION_FILE after a failure: it gates the first-boot unit,
# which would then never retry.
    echo "apply-skel: ${#failures[@]} file(s) failed to reconcile and were left untouched:" >&2
    printf '  %s\n' "${failures[@]}" >&2
    exit 1
fi

version_tmp="$(mktemp)"
printf '%s\n' "$new_version" > "$version_tmp"
durable_replace 644 "$version_tmp" "$VERSION_FILE"
rm -f "$version_tmp"

echo "apply-skel: done (sobarch-skel $new_version applied to $HOME)."
