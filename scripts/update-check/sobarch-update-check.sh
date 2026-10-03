#!/usr/bin/env bash
# Run daily by sobarch-update-check.timer (a systemd *user* unit, so it
# already has the logged-in user's session bus and needs none of
# notify-user.sh's root-to-session dance). Tells the user, via a
# clickable desktop notification, when:
#   - official repo packages or sobarch's own sobarch-skel/
#     sobarch-scripts have updates pending  -> Update System
#   - a newer Arch ISO than the one on the rescue partition exists
#     (only if rescue media was provisioned)  -> Refresh Rescue ISO
# Read-only and unprivileged throughout: `checkupdates` syncs into a
# temp DB copy, never the real one, and nothing here installs anything.
# Clicking a notification just opens the same fuzzel-menu action the
# user could have launched by hand, which does the privileged work.
#
# Each notification is shown once per distinct state (see offer()), so
# an unchanged backlog never re-nags daily; the system-updates one is
# deliberately re-armed weekly in case the first was missed.

set -uo pipefail

source /usr/local/lib/sobarch/rescue-iso-fetch.sh
source /usr/local/lib/sobarch/pinned-version.sh

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/sobarch/update-check"
SCRIPTS="$HOME/.config/hypr/scripts"
ICONS="$HOME/.config/sobarch/icons"
mkdir -p "$STATE_DIR"

# Launched from a user service, which has no HYPRLAND_INSTANCE_SIGNATURE
# of its own: pick the newest running instance instead so the click
# action opens its fuzzel menu inside the real session.
run_in_session() {
    local sig
    sig="$(ls -t "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr" 2>/dev/null | head -n1)"
    [[ -n "$sig" ]] || return 1
    HYPRLAND_INSTANCE_SIGNATURE="$sig" hyprctl dispatch exec "$1"
}

# offer KEY SIGNATURE ICON TITLE BODY ACTION_LABEL COMMAND
# Shows the notification unless SIGNATURE matches what was last shown
# for KEY. The click action is named "default", the one mako invokes
# on a plain left click. Backgrounded: notify-send --wait blocks until
# the notification is clicked or expires.
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
# checkupdates: exit 0 = updates listed, 2 = none, anything else = error
# (offline, mirror down), which is treated as "unknown", never "none".
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
    # Official count is left out of the signature on purpose: it drifts
    # daily on a rolling release, which would re-notify every day. The
    # ISO week re-arms it weekly instead.
    offer system "$(date +%G-%V) official=$((official > 0)) ${vendored[*]}" \
        "$ICONS/refresh.svg" "sobarch: updates available" "$body. Click to update." \
        "Update System" "sobarch update --gui"
fi

# --- rescue ISO -----------------------------------------------------
# Only meaningful if rescue media was provisioned (the RESCUE label
# exists) and this system recorded which ISO it holds (the stamp).
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
