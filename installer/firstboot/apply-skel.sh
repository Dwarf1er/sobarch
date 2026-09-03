#!/usr/bin/env bash
# Deploys/reconciles /usr/share/sobarch/skel/ (the `sobarch-skel`
# package) into $HOME, using the three-way `diff3`
# reconciliation implemented below.
#
# Authored once, here, for the first-boot hook's initial skel
# deployment. `sobarch update-config` later
# exposes this exact script, unmodified, as a user-invoked command,
# with its own interactive [K]eep/[U]se-new/[E]dit/[S]kip walkthrough
# for any `.sobarch-new` files layered on top; prompting is not this
# script's concern. With no baseline recorded yet, every file below has
# nothing to compare against, so the merge trivially resolves to "take
# new": first boot is just this mechanism's first invocation, not a
# separate copy path.
#
# Must run as the target user, not root: it writes into that user's
# $HOME and state directory. `sobarch-firstboot-skel.service` runs it
# via systemd's User=, which populates $HOME/$USER itself.

set -euo pipefail

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

empty_file="$(mktemp)"
merge_tmp="$(mktemp)"
trap 'rm -f "$empty_file" "$merge_tmp"' EXIT

conflicts=()
failures=()

# -a/--text: without it, diff3 refuses outright on any binary skel file
# (e.g. the default wallpaper) with "Binary files ... differ", even in
# the trivial no-baseline case where one side is untouched and the
# merge should just pass the other side through unchanged. Confirmed
# directly (a real hard failure on every first boot, not a theoretical
# one) before shipping this.
while IFS= read -r -d '' new_file; do
    rel="${new_file#"$SKEL_SRC"/}"
    current_file="$HOME/$rel"
    baseline_file="$BASELINE_DIR/$rel"

    current_input="$current_file"
    [[ -e "$current_input" ]] || current_input="$empty_file"
    baseline_input="$baseline_file"
    [[ -e "$baseline_input" ]] || baseline_input="$empty_file"

    rc=0
    diff3 -a -m "$current_input" "$baseline_input" "$new_file" > "$merge_tmp" || rc=$?

    mode="$(stat -c%a "$new_file")"
    case "$rc" in
        0)
            # Clean merge: apply it, and advance this file's baseline to
            # the version just applied.
            install -Dm"$mode" "$merge_tmp" "$current_file"
            install -Dm"$mode" "$new_file" "$baseline_file"
            ;;
        1)
            # Genuine conflict (both sides changed since the last
            # recorded baseline): never touch the user's file. Drop the
            # merged-with-conflict-markers result alongside it,
            # `.pacnew`-style, and deliberately leave this file's
            # baseline untouched, so it keeps being detected as
            # unresolved on every future run until it actually is
            # (interactive resolution is `update-config`'s job, not
            # this script).
            install -Dm"$mode" "$merge_tmp" "$current_file.sobarch-new"
            conflicts+=("$rel")
            ;;
        *)
            # Hard failure (diff3 itself errored): report it, touch
            # nothing for this file, but keep processing the rest
            # rather than aborting the whole pass over one bad file.
            failures+=("$rel (diff3 exited $rc)")
            ;;
    esac
done < <(find "$SKEL_SRC" -type f -print0)

printf '%s\n' "$new_version" > "$VERSION_FILE"

if ((${#conflicts[@]})); then
    echo "apply-skel: ${#conflicts[@]} file(s) have local changes that conflict with the new defaults;" \
        "new versions were written alongside as .sobarch-new (run 'sobarch update-config --review' to resolve):"
    printf '  %s\n' "${conflicts[@]}"
fi

if ((${#failures[@]})); then
    echo "apply-skel: ${#failures[@]} file(s) failed to reconcile and were left untouched:" >&2
    printf '  %s\n' "${failures[@]}" >&2
    exit 1
fi

echo "apply-skel: done (sobarch-skel $new_version applied to $HOME)."
