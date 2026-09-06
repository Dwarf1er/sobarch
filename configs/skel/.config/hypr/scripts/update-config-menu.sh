#!/usr/bin/env bash
# Exposes apply-skel.sh (installed at /usr/local/lib/sobarch/apply-skel.sh
# by the first-boot hook, decision 11) as a user-invoked action: refresh
# sobarch-skel, run the diff3 reconciliation, then walk any resulting
# conflicts interactively so nothing is left silently unresolved.
#
# Runs as the logged-in user throughout (apply-skel.sh must, since it
# writes into $HOME); the one privileged step (refreshing the
# sobarch-skel package itself) goes through pkexec, the same
# PolicyKit path hyprpolkitagent already provides for every other
# GUI-triggered privileged action on this desktop.
#
# --review re-enters the same conflict walkthrough below for whatever
# .sobarch-new files are still on disk (skipped earlier, or the
# session was closed partway through), skipping the refresh+apply step
# above it: same logic, not a second implementation.

set -euo pipefail

APPLY_SKEL="/usr/local/lib/sobarch/apply-skel.sh"
AUR_SYNC="/usr/local/lib/sobarch/aur-sync.sh"
SKEL_SRC="/usr/share/sobarch/skel"
BASELINE_DIR="$HOME/.local/state/sobarch/skel-baseline"

review_only=false
[[ "${1:-}" == "--review" ]] && review_only=true

if ! $review_only; then
    if ! pkexec "$AUR_SYNC" sobarch-skel; then
        notify-send "sobarch: update config" \
            "Refreshing sobarch-skel failed (offline?); continuing with the currently installed version."
    fi
    if ! "$APPLY_SKEL"; then
        notify-send -u critical "sobarch: update config" "apply-skel.sh failed; check its output for details."
        exit 1
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
        install -Dm"$mode" "$new" "$original"
        install -Dm"$mode" "$new" "$baseline"
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
                install -Dm"$mode" "$new" "$baseline"
                rm -f "$f"
                resolved=$((resolved + 1))
                break
                ;;
            "[U] Use new")
                install -Dm"$mode" "$new" "$original"
                install -Dm"$mode" "$new" "$baseline"
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
                install -Dm"$mode" "$f" "$original"
                install -Dm"$mode" "$new" "$baseline"
                rm -f "$f"
                resolved=$((resolved + 1))
                break
                ;;
            "[A] Use new for all remaining")
                use_new_for_rest=true
                install -Dm"$mode" "$new" "$original"
                install -Dm"$mode" "$new" "$baseline"
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
    "$resolved conflict(s) resolved, $skipped left for review (Setup -> Review Conflicts)."
