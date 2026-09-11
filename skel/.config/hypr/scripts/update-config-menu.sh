#!/usr/bin/env bash
# Exposes apply-skel.sh (installed at /usr/local/lib/sobarch/apply-skel.sh
# by the first-boot hook, decision 11) as a user-invoked action: refresh
# sobarch-skel, run the diff3 reconciliation, then walk any resulting
# conflicts interactively so nothing is left silently unresolved.
#
# Runs as the logged-in user throughout (apply-skel.sh must, since it
# writes into $HOME); the one privileged step (refreshing the
# sobarch-skel and sobarch-scripts packages themselves) goes through
# pkexec, the same PolicyKit path hyprpolkitagent already provides for
# every other GUI-triggered privileged action on this desktop.
#
# --review re-enters the same conflict walkthrough below for whatever
# .sobarch-new files are still on disk (skipped earlier, or the
# session was closed partway through), skipping the refresh+apply step
# above it: same logic, not a second implementation.

set -euo pipefail

# `install` (used throughout apply-skel.sh and the walkthrough below)
# replaces a file via a fresh inode, not an in-place write (confirmed:
# its destination's inode number changes across a run). Hyprland's own
# config auto-reload is documented to break on exactly that replace
# pattern (hyprwm/Hyprland discussion #11848: a rename-style replace
# can desync its inotify watch), which is what produced the transient
# "cannot open .../hyprland.lua" error a real run of this script hit.
# `hyprctl reload` doesn't depend on that watch at all, so it's run
# unconditionally on every exit path here rather than only when
# hyprland.lua specifically was touched: cheap, idempotent, and safe to
# run even when nothing changed or this session isn't Hyprland (a
# missing `hyprctl` or no running compositor both just no-op below).
trap 'hyprctl reload >/dev/null 2>&1 || true' EXIT

# Shared with apply-skel.sh (installer/firstboot/durable-replace.sh):
# a crash-safe replacement for `install -Dm"$mode" src dest`. A real
# run hit the gap the plain `install` calls below used to have: the
# desktop froze mid-update, was force shut down, and every file the
# walkthrough had touched so far came back zero-length on reboot.
source /usr/local/lib/sobarch/durable-replace.sh

APPLY_SKEL="/usr/local/lib/sobarch/apply-skel.sh"
BUILD_TINTY_TEMPLATES="/usr/local/lib/sobarch/build-tinty-templates.sh"
AUR_SYNC="/usr/local/lib/sobarch/aur-sync.sh"
SKEL_SRC="/usr/share/sobarch/skel"
BASELINE_DIR="$HOME/.local/state/sobarch/skel-baseline"

review_only=false
[[ "${1:-}" == "--review" ]] && review_only=true

if ! $review_only; then
    # aur-sync.sh's own version check (pinned .SRCINFO vs installed)
    # needs no root at all -- only the rebuild/install it performs
    # once one is actually pending does. pkexec always prompts for
    # authentication before the command even runs, though, regardless
    # of whether it then finds nothing to do -- the overwhelmingly
    # common case here, since these packages change far less often than
    # "Update Config" gets clicked. Checked here, unprivileged, first,
    # so a no-op run never has to ask for a password just to discover
    # that. Same GitHub master branch aur-sync.sh's own fetch reads
    # from, just one small file per package instead of the whole repo
    # tarball.
    #
    # sobarch-scripts (apply-skel.sh, durable-replace.sh, aur-sync.sh
    # itself, etc.) is checked here alongside sobarch-skel, not just
    # skel alone: it used to be refreshed unconditionally on every
    # aur-sync.sh run regardless of pkexec even firing, but now that
    # it's a real pacman-tracked package it only gets refreshed when
    # actually named as an explicit target below, so it has to be
    # checked the same way skel is or a pending fix to it would go
    # unnoticed whenever skel itself happened to be up to date.
    update_pending=false
    to_refresh=()
    for pkg in sobarch-skel sobarch-scripts; do
        installed="$(pacman -Q "$pkg" 2>/dev/null | awk '{print $2}' || true)"
        if [[ -z "$installed" ]]; then
            continue
        fi
        pkg_pending=false
        srcinfo_url="https://raw.githubusercontent.com/Dwarf1er/sobarch/master/packages/custom/$pkg/.SRCINFO"
        if srcinfo="$(curl -fsSL "$srcinfo_url" 2>/dev/null)"; then
            epoch="$(awk -F' = ' '/^[[:space:]]*epoch = /{print $2; exit}' <<<"$srcinfo")"
            pkgver="$(awk -F' = ' '/^[[:space:]]*pkgver = /{print $2; exit}' <<<"$srcinfo")"
            pkgrel="$(awk -F' = ' '/^[[:space:]]*pkgrel = /{print $2; exit}' <<<"$srcinfo")"
            if [[ -n "$pkgver" && -n "$pkgrel" ]]; then
                if [[ -n "$epoch" ]]; then
                    pinned="${epoch}:${pkgver}-${pkgrel}"
                else
                    pinned="${pkgver}-${pkgrel}"
                fi
                (( $(vercmp "$pinned" "$installed") > 0 )) && pkg_pending=true
            fi
        fi
        # else: couldn't tell (offline, GitHub hiccup, etc.) -- pkexec
        # would only hit the same wall this curl call just did, so
        # leave pkg_pending false rather than demand a password for a
        # call that's this likely to fail anyway.
        if $pkg_pending; then
            update_pending=true
            to_refresh+=("$pkg")
        fi
    done

    # Base-required AUR packages (decision 3) added to
    # base-required-packages.txt after this system's own install ran
    # are never picked up by aur-sync.sh's own hook: its sync mode (no
    # args) only updates packages already `pacman -Q`-installed, the
    # same guarantee that stops it from force-installing an unselected
    # profile package. So a name added after the fact would otherwise
    # stay missing here forever. Checked the same unprivileged-first
    # way as above, but on presence, not version: a missing package has
    # no installed version to compare against.
    base_pkgs_url="https://raw.githubusercontent.com/Dwarf1er/sobarch/master/scripts/aur-sync/base-required-packages.txt"
    if base_pkgs_list="$(curl -fsSL "$base_pkgs_url" 2>/dev/null)"; then
        mapfile -t base_pkgs < <(sed 's/#.*//' <<<"$base_pkgs_list" | awk 'NF{$1=$1;print}')
        for pkg in "${base_pkgs[@]}"; do
            if ! pacman -Q "$pkg" &>/dev/null; then
                update_pending=true
                to_refresh+=("$pkg")
            fi
        done
    fi
    # else: couldn't tell (offline, GitHub hiccup, etc.) -- same
    # reasoning as the per-package curl above, leave it for next time
    # rather than demand a password for a call this likely to fail too.

    if $update_pending && ! pkexec "$AUR_SYNC" "${to_refresh[@]}"; then
        notify-send "sobarch: update config" \
            "Refreshing ${to_refresh[*]} failed (offline?); continuing with the currently installed version(s)."
    fi
    if ! "$APPLY_SKEL"; then
        notify-send -u critical "sobarch: update config" "apply-skel.sh failed; check its output for details."
        exit 1
    fi

    # A skel update can change sobarch's own local tinty templates
    # (~/.config/sobarch/tinty-templates/); apply-skel.sh only writes
    # the templates themselves, never re-renders them (tinty's own
    # apply/install/sync never do that either, see config.toml), so
    # every scheme has to be rebuilt here or theme switching keeps
    # using the stale, previously-built output.
    if ! "$BUILD_TINTY_TEMPLATES"; then
        notify-send -u critical "sobarch: update config" \
            "Rebuilding tinty theme templates failed; run 'tinty build' on ~/.config/sobarch/tinty-templates/* manually to retry."
    fi
fi

mapfile -t conflicts < <(find "$HOME" -name '*.sobarch-new' 2>/dev/null | sort)

if ((${#conflicts[@]} == 0)); then
    $review_only && notify-send "sobarch: update config" "No pending conflicts."
    exit 0
fi

resolved=0
skipped=0
use_new_for_rest=false

for f in "${conflicts[@]}"; do
    original="${f%.sobarch-new}"
    rel="${original#"$HOME"/}"
    baseline="$BASELINE_DIR/$rel"
    new="$SKEL_SRC/$rel"

    if [[ ! -e "$new" ]]; then
        # The file no longer exists in the current sobarch-skel at all
        # (removed upstream since the pending conflict was recorded):
        # nothing sensible to offer beyond dropping the stale .sobarch-new.
        rm -f "$f"
        resolved=$((resolved + 1))
        continue
    fi
    mode="$(stat -c%a "$new")"

    if $use_new_for_rest; then
        durable_replace "$mode" "$new" "$original"
        durable_replace "$mode" "$new" "$baseline"
        rm -f "$f"
        resolved=$((resolved + 1))
        continue
    fi

    while true; do
        choice=$(printf '%s\n' \
            "[K] Keep mine" \
            "[U] Use new" \
            "[D] Diff" \
            "[E] Edit now" \
            "[S] Skip for later" \
            "[A] Use new for all remaining" \
            | fuzzel --dmenu --prompt "$rel: ")

        case "$choice" in
            "[K] Keep mine")
                durable_replace "$mode" "$new" "$baseline"
                rm -f "$f"
                resolved=$((resolved + 1))
                break
                ;;
            "[U] Use new")
                durable_replace "$mode" "$new" "$original"
                durable_replace "$mode" "$new" "$baseline"
                rm -f "$f"
                resolved=$((resolved + 1))
                break
                ;;
            "[D] Diff")
                diff_tmp="$(mktemp)"
                {
                    echo "=== your changes (baseline -> current) ==="
                    diff -u "$baseline" "$original" 2>/dev/null || true
                    echo
                    echo "=== upstream changes (baseline -> new) ==="
                    diff -u "$baseline" "$new" 2>/dev/null || true
                } > "$diff_tmp"
                kitty -e less "$diff_tmp"
                rm -f "$diff_tmp"
                continue
                ;;
            "[E] Edit now")
                # Edits the pending merge (conflict markers and all, the
                # same content pacdiff-style tools show for a .pacnew),
                # not a blank slate: both sides are already visible in it.
                kitty -e "${EDITOR:-nano}" "$f"
                durable_replace "$mode" "$f" "$original"
                durable_replace "$mode" "$new" "$baseline"
                rm -f "$f"
                resolved=$((resolved + 1))
                break
                ;;
            "[A] Use new for all remaining")
                use_new_for_rest=true
                durable_replace "$mode" "$new" "$original"
                durable_replace "$mode" "$new" "$baseline"
                rm -f "$f"
                resolved=$((resolved + 1))
                break
                ;;
            "[S] Skip for later"|"")
                skipped=$((skipped + 1))
                break
                ;;
        esac
    done
done

notify-send "sobarch: update config" \
    "$resolved conflict(s) resolved, $skipped left for review (Sobarch -> Review Conflicts)."
