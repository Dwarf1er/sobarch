#!/usr/bin/env bash
# Daily, from a user timer: notifies about pending system updates and a
# newer Arch ISO for the rescue partition. Read-only; clicking opens the
# matching menu action. Each notification is shown once per state.

set -uo pipefail

source /usr/local/lib/sobarch/rescue-iso-fetch.sh
source /usr/local/lib/sobarch/pinned-version.sh

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/sobarch/update-check"
SCRIPTS="$HOME/.config/hypr/scripts"
ICONS="$HOME/.config/sobarch/icons"
mkdir -p "$STATE_DIR"

# User services lack HYPRLAND_INSTANCE_SIGNATURE, so use the newest instance.
run_in_session() {
    local sig
    sig="$(ls -t "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr" 2>/dev/null | head -n1)"
    [[ -n "$sig" ]] || return 1
    HYPRLAND_INSTANCE_SIGNATURE="$sig" hyprctl dispatch exec "$1"
}

# offer KEY SIGNATURE ICON TITLE BODY ACTION_LABEL COMMAND
# Shows the notification unless SIGNATURE matches the last one for KEY.
# "default" is mako's left-click action.
offer() {
    local key="$1" sig="$2" icon="$3" title="$4" body="$5" label="$6" cmd="$7"
    [[ "$(cat "$STATE_DIR/$key" 2>/dev/null)" == "$sig" ]] && return 0
    echo "$sig" >"$STATE_DIR/$key"
    (
        action="$(timeout 600 notify-send --wait -t 600000 -A "default=$label" -i "$icon" "$title" "$body")"
        [[ "$action" == default ]] && run_in_session "$cmd"
    ) &
}

# --- system updates -------------------------------------------------
# checkupdates exits 2 for none; other failures count as unknown, not none.
official=0
if updates="$(checkupdates 2>/dev/null)"; then
    official="$(wc -l <<<"$updates")"
fi

vendored=()
for pkg in sobarch-skel sobarch-scripts; do
    vendored_update_pending "$pkg" && vendored+=("$pkg")
done

if ((official > 0 || ${#vendored[@]} > 0)); then
    parts=()
    ((official > 0)) && parts+=("$official package update(s)")
    ((${#vendored[@]} > 0)) && parts+=("sobarch config/scripts update (${vendored[*]})")
    body="${parts[0]}${parts[1]:+, ${parts[1]}}"
    # The official count drifts daily, so it stays out of the signature;
    # the ISO week re-arms the notification weekly instead.
    offer system "$(date +%G-%V) official=$((official > 0)) ${vendored[*]}" \
        "$ICONS/refresh.svg" "sobarch: updates available" "$body. Click to update." \
        "Update System" "sobarch update --gui"
fi

# --- rescue ISO -----------------------------------------------------
if lsblk -rno LABEL 2>/dev/null | grep -qx RESCUE && [[ -r "$RESCUE_ISO_STAMP" ]]; then
    if sums="$(curl -fsSL "$MIRROR_URL/sha256sums.txt" 2>/dev/null)"; then
        latest="$(awk '/archlinux-x86_64\.iso$/{print $1; exit}' <<<"$sums")"
        if [[ -n "$latest" && "$latest" != "$(cat "$RESCUE_ISO_STAMP")" ]]; then
            offer rescue "$latest" "$ICONS/device-usb.svg" "sobarch: new rescue ISO" \
                "A newer Arch ISO is available for your rescue partition. Click to refresh it." \
                "Refresh Rescue ISO" "bash '$SCRIPTS/refresh-rescue-menu.sh'"
        fi
    fi
fi

wait
