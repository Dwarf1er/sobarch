#!/usr/bin/env bash
# Full system update: pacman -Syu, aur-sync.sh, apply-skel.sh, then an
# interactive walkthrough of any .sobarch-new conflicts.
#
#   update-system.sh [--review]         terminal (sudo); `sobarch update`
#   update-system.sh --gui [--review]   desktop (fuzzel, pkexec)
# --review only runs the conflict walkthrough.
#
# Runs as the user since apply-skel.sh writes into $HOME.

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

# Replacing files breaks Hyprland's config auto-reload, so always reload on exit.
empty_file="$(mktemp)"
trap 'hyprctl reload >/dev/null 2>&1 || true; rm -f "$empty_file"' EXIT

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
LAST_UPDATE_FILE="$HOME/.local/state/sobarch/last-update"

ICONS="$HOME/.config/sobarch/icons"
TITLE="sobarch: update system"

# --- front end ------------------------------------------------------
# Everything below talks to the user only through these functions.
PROG_ID=0
if [[ "$MODE" == gui ]]; then
    source "$HOME/.config/hypr/scripts/confirm.sh"
    source "$HOME/.config/hypr/scripts/notify-progress.sh"
    PACMAN_FLAGS="--noconfirm" # no terminal to answer prompts in

    notice() { notify-send -u "$1" -i "$ICONS/refresh.svg" "$TITLE" "$2"; }
    progress_start() { PROG_ID=$(notify_progress normal "$TITLE" "$1" 0 persist); }
    progress_end() { notify_progress "$1" "$TITLE" "$2" "$PROG_ID" >/dev/null; }
    ask_yes() { confirm "$1" "${2:-Yes}"; }
    as_root() { pkexec "$@"; }
    # Prints the choice string matched by the walkthrough; empty means skip.
    # Falls back to plain fuzzel when menu-lib.sh isn't deployed yet.
    if source "$HOME/.config/hypr/scripts/menu-lib.sh" 2>/dev/null; then
        pick_action() {
            menu_reset
            menu_add "[K] Keep mine" "Keep Mine" check.svg
            menu_add "[U] Use new" "Use New Version" download.svg
            menu_add "[D] Diff" "Show Differences" git-merge.svg
            menu_add "[E] Edit now" "Edit the Merge" file-text.svg
            menu_add "[S] Skip for later" "Skip for Now" x.svg
            menu_add "[A] Use new for all remaining" "Use New for All Remaining" refresh.svg
            menu_show conflict "$1" && printf '%s\n' "$MENU_ID"
        }
    else
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
    fi
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

# Limine, ly, and Plymouth have no reload, so re-run their setup scripts
# whenever sobarch-skel changes. Each no-ops when nothing changed.
reapply_theming() {
    [[ -x "$LIMINE_THEME_SETUP" && -x "$LY_THEME_SETUP" && -x "$PLYMOUTH_SETUP" ]] || return 0
    if ! as_root bash -c "'$LIMINE_THEME_SETUP' && '$LY_THEME_SETUP' && '$PLYMOUTH_SETUP'"; then
        notice normal "Refreshing boot/greeter/splash theming failed; limine.conf, ly's config.ini, or the Plymouth theme may be stale until the next Update System run."
    fi
}

# Titles of Arch news items published after epoch $1; fails if the feed
# can't be fetched.
recent_news() {
    local feed date_str title
    feed="$(curl -fsS --max-time 8 https://archlinux.org/feeds/news/ 2>/dev/null)" || return 1
    while IFS='|' read -r date_str title; do
        (($(date -d "$date_str" +%s 2>/dev/null || echo 0) > $1)) || continue
        sed -e 's/&amp;/\&/g; s/&lt;/</g; s/&gt;/>/g; s/&quot;/"/g; s/&#39;/'"'"'/g' <<<"$title"
    done < <(awk 'BEGIN { RS = "</item>" } /<item>/ {
        t = $0; sub(/.*<title>/, "", t); sub(/<\/title>.*/, "", t)
        d = $0; sub(/.*<pubDate>/, "", d); sub(/<\/pubDate>.*/, "", d)
        print d "|" t }' <<<"$feed")
}

# Warn about news since the last successful update; returns 1 to abort.
check_news() {
    local since news
    since="$(cat "$LAST_UPDATE_FILE" 2>/dev/null || date -d '14 days ago' +%s)"
    news="$(recent_news "$since")" || return 0
    [[ -n "$news" ]] || return 0
    ask_yes "Arch news since your last update (some need manual steps first):
$news
Read them at archlinux.org/news." "Update Anyway"
}

# Reports what an update can leave wrong; quiet when all is well.
post_update_check() {
    local failed problems=()
    failed="$({ systemctl --failed --no-legend --plain; systemctl --user --failed --no-legend --plain; } 2>/dev/null | awk '{print $1}' | paste -sd' ')"
    [[ -n "$failed" ]] && problems+=("failed units: $failed")
    [[ -d "/usr/lib/modules/$(uname -r)" ]] || problems+=("the kernel was updated; reboot to use it")
    ((${#problems[@]} == 0)) && return 0
    notice normal "After the update: $(printf '%s; ' "${problems[@]}" | sed 's/; $//')."
}

if ! $review_only; then
    if ! check_news; then
        notice normal "Update cancelled."
        exit 0
    fi
    # UEFI only: a stale BOOTX64.EFI after a limine upgrade can leave the machine
    # unbootable. Exits 12 so the package steps below still count as done.
    LIMINE_SYNC_CHECK='[ ! -f /boot/EFI/BOOT/BOOTX64.EFI ] || cmp -s /usr/share/limine/BOOTX64.EFI /boot/EFI/BOOT/BOOTX64.EFI || exit 12'
    # One privileged call for all of it, so one password prompt. Exit codes say
    # which part failed; none aborts the config sync below.
    skel_before="$(pacman -Q sobarch-skel 2>/dev/null || true)"
    progress_start "Updating system packages (pacman -Syu)..."
    rc=0
    as_root bash -c "pacman -Syu $PACMAN_FLAGS || exit 10; '$AUR_SYNC' || exit 11; $LIMINE_SYNC_CHECK" || rc=$?
    case "$rc" in
        0 | 12)
            progress_end normal "System packages up to date."
            mkdir -p "$(dirname "$LAST_UPDATE_FILE")"
            date +%s >"$LAST_UPDATE_FILE"
            [[ "$rc" == 12 ]] && notice critical "Limine's boot binary in /boot/EFI/BOOT differs from the installed one; copy /usr/share/limine/BOOTX64.EFI over it before rebooting."
            ;;
        10) progress_end critical "pacman -Syu failed (offline, or a conflict that needs a terminal); continuing with config sync only." ;;
        11) progress_end critical "Official packages updated, but syncing vendored AUR/custom packages failed; see /var/log/sobarch/aur-sync.log." ;;
        *) progress_end critical "System update didn't run (authentication cancelled?); continuing with config sync only." ;;
    esac
    [[ "$(pacman -Q sobarch-skel 2>/dev/null || true)" != "$skel_before" ]] && reapply_theming

    # Check unprivileged first so a no-op run never prompts for a password.
    # sobarch-scripts is checked too, so a new update flow applies this run.
    update_pending=false
    to_refresh=()
    for pkg in sobarch-skel sobarch-scripts; do
        if vendored_update_pending "$pkg"; then
            update_pending=true
            to_refresh+=("$pkg")
        fi
    done

    # Base-required packages added after this system was installed are never
    # installed by sync mode, which only touches installed packages.
    base_pkgs_url="https://raw.githubusercontent.com/Dwarf1er/sobarch/$(sobarch_branch)/scripts/aur-sync/base-required-packages.txt"
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

    # apply-skel.sh only copies tinty templates; they must be re-rendered.
    if ! "$BUILD_TINTY_TEMPLATES"; then
        notice critical "Rebuilding tinty theme templates failed; run 'tinty build' on ~/.config/sobarch/tinty-templates/* manually to retry."
    fi
    post_update_check
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
        # Removed from sobarch-skel since the conflict was recorded.
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
                ask_yes "Overwrite $rel with the new version? Your changes to it are discarded." Overwrite || continue
                durable_replace "$mode" "$new" "$original"
                durable_replace "$mode" "$new" "$baseline"
                rm -f "$f"
                resolved=$((resolved + 1))
                break
                ;;
            "[D] Diff")
                # A first-time conflict may have no baseline yet.
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
                edit_file "$f"
                durable_replace "$mode" "$f" "$original"
                durable_replace "$mode" "$new" "$baseline"
                rm -f "$f"
                resolved=$((resolved + 1))
                break
                ;;
            "[A] Use new for all remaining")
                ask_yes "Use the new version for every remaining conflict? Your changes to those files are discarded." "Use New for All" || continue
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
