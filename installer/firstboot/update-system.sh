#!/usr/bin/env bash
# The full system update: a `pacman -Syu`, then aur-sync.sh in sync mode
# for vendored AUR/custom packages, then (via apply-skel.sh, decision
# 11) the diff3 skel reconciliation, then an interactive walk through
# any resulting conflicts so nothing is left silently unresolved.
# Additive: a raw `pacman -Syu` from a terminal still works on its own,
# with the pacman hook as its safety net for vendored packages
# (decision #3).
#
# One implementation behind two front ends, chosen by flag:
#   update-system.sh [--review]         terminal: plain prompts, sudo,
#                                       works over SSH. This is what
#                                       `sobarch update` /
#                                       `sobarch review-conflicts` run.
#   update-system.sh --gui [--review]   desktop: fuzzel pickers, mako
#                                       notifications, pkexec. What
#                                       Sobarch -> Update System / Review
#                                       Conflicts runs (update-system-
#                                       menu.sh, via `sobarch update
#                                       --gui`).
# --review skips the update itself and re-enters just the conflict
# walkthrough for whatever .sobarch-new files are still on disk
# (skipped earlier, or the session was closed partway through).
#
# Runs as the logged-in user throughout (apply-skel.sh must, since it
# writes into $HOME); the privileged steps go through sudo (terminal)
# or pkexec (desktop, the same PolicyKit path hyprpolkitagent already
# provides for every other GUI-triggered privileged action).

set -euo pipefail

MODE=tty
review_only=false
for arg in "$@"; do
    case "$arg" in
        --gui) MODE=gui ;;
        --review) review_only=true ;;
        *) echo "update-system.sh: unknown argument '$arg'" >&2; exit 2 ;;
    esac
done

if ((EUID == 0)); then
    echo "update-system.sh: run this as your own user, not root; it asks for sudo itself, and reconciles files in your \$HOME." >&2
    exit 1
fi

# `install` (used throughout apply-skel.sh and the walkthrough below)
# replaces a file via a fresh inode, not an in-place write. Hyprland's
# own config auto-reload is documented to break on exactly that replace
# pattern (hyprwm/Hyprland discussion #11848), which is what produced a
# transient "cannot open .../hyprland.lua" error on a real run.
# `hyprctl reload` doesn't depend on that watch, so it's run
# unconditionally on every exit path: cheap, idempotent, and a no-op
# when `hyprctl` is missing or there's no running compositor (an SSH
# session, say).
empty_file="$(mktemp)"
trap 'hyprctl reload >/dev/null 2>&1 || true; rm -f "$empty_file"' EXIT

# Shared with apply-skel.sh: a crash-safe replacement for `install -Dm"$mode"
# src dest`. A real run hit the gap plain `install` calls used to have:
# the desktop froze mid-update, was force shut down, and every file the
# walkthrough had touched so far came back zero-length on reboot.
source /usr/local/lib/sobarch/durable-replace.sh
source /usr/local/lib/sobarch/pinned-version.sh

APPLY_SKEL="/usr/local/lib/sobarch/apply-skel.sh"
BUILD_TINTY_TEMPLATES="/usr/local/lib/sobarch/build-tinty-templates.sh"
AUR_SYNC="/usr/local/lib/sobarch/aur-sync.sh"
LIMINE_THEME_SETUP="/usr/local/lib/sobarch/limine-theme-setup.sh"
LY_THEME_SETUP="/usr/local/lib/sobarch/ly-theme-setup.sh"
PLYMOUTH_SETUP="/usr/local/lib/sobarch/plymouth-setup.sh"
SKEL_SRC="/usr/share/sobarch/skel"
BASELINE_DIR="$HOME/.local/state/sobarch/skel-baseline"

ICONS="$HOME/.config/sobarch/icons"
TITLE="sobarch: update system"

# --- front end ------------------------------------------------------
# Everything below this block is mode-agnostic: it only ever talks to
# the user through these functions.
PROG_ID=0
if [[ "$MODE" == gui ]]; then
    source "$HOME/.config/hypr/scripts/confirm.sh"
    source "$HOME/.config/hypr/scripts/notify-progress.sh"
    PACMAN_FLAGS="--noconfirm" # no terminal to answer prompts in

    notice() { notify-send -u "$1" -i "$ICONS/refresh.svg" "$TITLE" "$2"; }
    progress_start() { PROG_ID=$(notify_progress normal "$TITLE" "$1" 0 persist); }
    progress_end() { notify_progress "$1" "$TITLE" "$2" "$PROG_ID" >/dev/null; }
    ask_yes() { confirm "$1"; }
    as_root() { pkexec "$@"; }
    # Prints one of the canonical choice strings the walkthrough's
    # `case` matches on; empty means skip.
    pick_action() {
        printf '%s\n' \
            "[K] Keep mine" \
            "[U] Use new" \
            "[D] Diff" \
            "[E] Edit now" \
            "[S] Skip for later" \
            "[A] Use new for all remaining" \
            | fuzzel --dmenu --prompt "$1: "
    }
    show_file() { kitty -e less "$1"; }
    edit_file() { kitty -e "${EDITOR:-nvim}" "$1"; }
else
    PACMAN_FLAGS=""
    notice() {
        if [[ "$1" == critical ]]; then echo "$TITLE: $2" >&2; else echo "$TITLE: $2"; fi
    }
    progress_start() { echo "$TITLE: $1"; }
    progress_end() { notice "$1" "$2"; }
    ask_yes() {
        local answer
        read -r -p "$1 [y/N] " answer || answer=n
        [[ "$answer" =~ ^[Yy] ]]
    }
    as_root() { sudo "$@"; }
    pick_action() {
        local answer
        read -r -p "$1: [K]eep mine  [U]se new  [D]iff  [E]dit  [S]kip  use new for [A]ll remaining > " answer || answer=S
        case "${answer^^}" in
            K) echo "[K] Keep mine" ;;
            U) echo "[U] Use new" ;;
            D) echo "[D] Diff" ;;
            E) echo "[E] Edit now" ;;
            A) echo "[A] Use new for all remaining" ;;
            *) echo "[S] Skip for later" ;;
        esac
    }
    show_file() { less "$1"; }
    edit_file() { "${EDITOR:-nvim}" "$1"; }
fi

# Re-applies boot/greeter/splash theming from whatever branding
# sobarch-skel is currently at. Limine/ly/Plymouth have no "reload" of
# their own (a bootloader menu, a greeter, and an initramfs-baked
# splash, none of which are running right now), so this is what makes
# limine.conf/ly's config.ini/the Plymouth theme ever change on an
# already-installed system at all -- otherwise they're install-time-
# only. All three scripts already no-op cheaply when nothing changed,
# so it runs whenever sobarch-skel was refreshed rather than trying to
# detect whether branding/ itself was part of it.
reapply_theming() {
    [[ -x "$LIMINE_THEME_SETUP" && -x "$LY_THEME_SETUP" && -x "$PLYMOUTH_SETUP" ]] || return 0
    if ! as_root bash -c "'$LIMINE_THEME_SETUP' && '$LY_THEME_SETUP' && '$PLYMOUTH_SETUP'"; then
        notice normal "Refreshing boot/greeter/splash theming failed; limine.conf, ly's config.ini, or the Plymouth theme may be stale until the next Update System run."
    fi
}

if ! $review_only; then
    # Full system update first: official packages, then vendored
    # AUR/custom ones, in one privileged call (one password prompt, not
    # two). The exit codes distinguish which half failed. Neither
    # failure aborts the rest of this script: skel reconciliation below
    # only needs whatever sobarch-skel is already installed, the same
    # continue-on-failure posture the targeted refresh further down
    # already takes.
    skel_before="$(pacman -Q sobarch-skel 2>/dev/null || true)"
    progress_start "Updating system packages (pacman -Syu)..."
    rc=0
    as_root bash -c "pacman -Syu $PACMAN_FLAGS || exit 10; '$AUR_SYNC' || exit 11" || rc=$?
    case "$rc" in
        0) progress_end normal "System packages up to date." ;;
        10) progress_end critical "pacman -Syu failed (offline, or a conflict that needs a terminal); continuing with config sync only." ;;
        11) progress_end critical "Official packages updated, but syncing vendored AUR/custom packages failed; see /var/log/sobarch/aur-sync.log." ;;
        *) progress_end critical "System update didn't run (authentication cancelled?); continuing with config sync only." ;;
    esac
    [[ "$(pacman -Q sobarch-skel 2>/dev/null || true)" != "$skel_before" ]] && reapply_theming

    # aur-sync.sh's own version check (pinned .SRCINFO vs installed)
    # needs no root at all -- only the rebuild/install it performs once
    # one is actually pending does. Privilege escalation always prompts
    # for authentication before the command even runs, regardless of
    # whether it then finds nothing to do -- the overwhelmingly common
    # case here. Checked unprivileged first, so a no-op run never asks
    # for a password just to discover that.
    #
    # sobarch-scripts is checked alongside sobarch-skel, not just skel
    # alone: as a real pacman-tracked package it only gets refreshed
    # when actually named as an explicit target below, so a pending fix
    # to it would otherwise go unnoticed whenever skel itself happened
    # to be up to date.
    update_pending=false
    to_refresh=()
    for pkg in sobarch-skel sobarch-scripts; do
        # Offline/GitHub hiccup: vendored_update_pending says "not
        # pending" -- escalation would only hit the same wall, so don't
        # demand a password for a call this likely to fail anyway.
        if vendored_update_pending "$pkg"; then
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
    # stay missing here forever. Checked on presence, not version: a
    # missing package has no installed version to compare against.
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

    if $update_pending; then
        # A pending refresh can mean a real from-source AUR rebuild
        # (aur-sync.sh), not just a fast repo-package bump: worth a
        # notification before escalation even starts, since otherwise
        # this is silent the whole time it runs.
        progress_start "Refreshing ${to_refresh[*]}..."
        if ! as_root "$AUR_SYNC" "${to_refresh[@]}"; then
            progress_end normal "Refreshing ${to_refresh[*]} failed (offline?); continuing with the currently installed version(s)."
        else
            progress_end normal "Refreshed ${to_refresh[*]}."
            reapply_theming
        fi
    fi
    if ! "$APPLY_SKEL"; then
        notice critical "apply-skel.sh failed; check its output for details."
        exit 1
    fi

    # A skel update can change sobarch's own local tinty templates
    # (~/.config/sobarch/tinty-templates/); apply-skel.sh only writes
    # the templates themselves, never re-renders them (tinty's own
    # apply/install/sync never do that either, see config.toml), so
    # every scheme has to be rebuilt here or theme switching keeps
    # using the stale, previously-built output.
    if ! "$BUILD_TINTY_TEMPLATES"; then
        notice critical "Rebuilding tinty theme templates failed; run 'tinty build' on ~/.config/sobarch/tinty-templates/* manually to retry."
    fi
fi

mapfile -t conflicts < <(find "$HOME" -name '*.sobarch-new' 2>/dev/null | sort)

if ((${#conflicts[@]} == 0)); then
    if $review_only; then
        notice normal "No pending conflicts."
    else
        notice normal "System updated; no conflicts."
    fi
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
        choice="$(pick_action "$rel" || true)"

        case "$choice" in
            "[K] Keep mine")
                durable_replace "$mode" "$new" "$baseline"
                rm -f "$f"
                resolved=$((resolved + 1))
                break
                ;;
            "[U] Use new")
                ask_yes "Overwrite $rel with the new version?" || continue
                durable_replace "$mode" "$new" "$original"
                durable_replace "$mode" "$new" "$baseline"
                rm -f "$f"
                resolved=$((resolved + 1))
                break
                ;;
            "[D] Diff")
                # A conflict recorded for the first time (e.g. a file
                # like .bashrc whose baseline was never written because
                # apply-skel.sh deliberately leaves it unset on
                # conflict) has no baseline file on disk at all.
                # Diffing against it would otherwise fail silently
                # (stderr discarded below) and show nothing; an empty
                # stand-in makes that case just show the whole
                # current/new file as one big addition instead.
                diff_baseline="$baseline"
                [[ -e "$diff_baseline" ]] || diff_baseline="$empty_file"
                diff_tmp="$(mktemp)"
                {
                    echo "=== your changes (baseline -> current) ==="
                    diff -u "$diff_baseline" "$original" 2>/dev/null || true
                    echo
                    echo "=== upstream changes (baseline -> new) ==="
                    diff -u "$diff_baseline" "$new" 2>/dev/null || true
                } > "$diff_tmp"
                show_file "$diff_tmp"
                rm -f "$diff_tmp"
                continue
                ;;
            "[E] Edit now")
                # Edits the pending merge (conflict markers and all, the
                # same content pacdiff-style tools show for a .pacnew),
                # not a blank slate: both sides are already visible in it.
                edit_file "$f"
                durable_replace "$mode" "$f" "$original"
                durable_replace "$mode" "$new" "$baseline"
                rm -f "$f"
                resolved=$((resolved + 1))
                break
                ;;
            "[A] Use new for all remaining")
                ask_yes "Use new for all remaining conflicts?" || continue
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

notice normal "$resolved conflict(s) resolved, $skipped left for review (Sobarch -> Review Conflicts, or: sobarch review-conflicts)."
