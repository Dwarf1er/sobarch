#!/usr/bin/env bash
# Installs the optional packages selected during install, deferred to
# first boot rather than the install session itself:
# this keeps the base install fast and minimal, and every
# profile is installed the same way regardless of whether it happens
# to contain an AUR package, rather than "ready immediately" for
# official-repo-only profiles and delayed for anything mixed with AUR.
#
# Run once by sobarch-firstboot-packages.service (its own
# ConditionPathExists on MARKER below): a failure here (e.g. no
# network yet) leaves MARKER unwritten, so it retries automatically on
# the next boot rather than being silently skipped forever.
#
# AUR packages aren't installed here yet: that needs packages/aur/'s
# vendored PKGBUILDs and a local build/update mechanism, which doesn't
# exist yet. They're left listed in AUR_LIST, unattended, for whenever
# that mechanism lands.

set -euo pipefail

SOBARCH_DIR="/etc/sobarch"
OFFICIAL_LIST="$SOBARCH_DIR/profile-packages-official.txt"
AUR_LIST="$SOBARCH_DIR/profile-packages-aur.txt"
MARKER="/var/lib/sobarch/profile-packages-installed"

# Best-effort desktop notification into the logged-in user's session:
# this runs as root with no controlling terminal, so a failure is
# otherwise invisible until someone thinks to check journalctl. A
# no-op if no graphical session is active yet (e.g. a network blip
# right after boot before anyone's logged in) or notify-send isn't
# installed.
#
# notify_user prints the notification's id (via -p) so a caller can
# pass it back in as replace_id to update that same notification in
# place, rather than piling up a new transient one per step.
notify_user() {
    local urgency="$1" title="$2" body="$3" replace_id="${4:-0}"
    command -v notify-send >/dev/null 2>&1 || { echo 0; return 0; }
    local session_user
    session_user="$(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $3; exit}')"
    [[ -n "$session_user" ]] || { echo 0; return 0; }
    local uid
    uid="$(id -u "$session_user" 2>/dev/null)" || { echo 0; return 0; }
    runuser -u "$session_user" -- env XDG_RUNTIME_DIR="/run/user/$uid" \
        notify-send -p -r "$replace_id" -u "$urgency" "$title" "$body" 2>/dev/null || echo 0
}
trap 'rc=$?; [[ $rc -eq 0 ]] || notify_user critical "sobarch: package install failed" \
    "Check: journalctl -u sobarch-firstboot-packages.service"; exit $rc' EXIT

mkdir -p "$(dirname "$MARKER")"

if [[ -s "$OFFICIAL_LIST" ]]; then
    mapfile -t packages <"$OFFICIAL_LIST"
    total=${#packages[@]}
    echo "sobarch-firstboot: installing $total selected package(s): ${packages[*]}"
    id=$(notify_user normal "sobarch: installing packages" "Installing $total selected package(s)...")
    n=0
    for pkg in "${packages[@]}"; do
        n=$((n + 1))
        id=$(notify_user normal "sobarch: installing packages" "Installing ($n/$total): $pkg" "$id")
        pacman -S --needed --noconfirm "$pkg"
    done
    notify_user critical "sobarch: installing packages" "$total package(s) installed." "$id" >/dev/null
else
    echo "sobarch-firstboot: no optional official-repo packages were selected."
fi

if [[ -s "$AUR_LIST" ]]; then
    echo "sobarch-firstboot: the following selected AUR package(s) were NOT installed" \
        "(packages/aur/ vendoring isn't implemented yet):"
    cat "$AUR_LIST"
fi

touch "$MARKER"
