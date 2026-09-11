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
# Selected AUR profile packages are built/installed the same way as
# any other vendored package (Phase 10's aur-sync.sh, deployed
# alongside this script): explicit-package mode, so only the packages
# actually selected get installed, never the full vendored set.

set -euo pipefail

SOBARCH_DIR="/etc/sobarch"
OFFICIAL_LIST="$SOBARCH_DIR/profile-packages-official.txt"
AUR_LIST="$SOBARCH_DIR/profile-packages-aur.txt"
MARKER="/var/lib/sobarch/profile-packages-installed"

# md-package_down (Nerd Fonts Material Design Icons, same family as
# skel's own menu scripts, e.g. system-menu.sh's md-volume-high/
# md-wifi): a package with a download arrow, prefixed on every
# notification title here for the same visual consistency those menus
# already have.
GLYPH=$'\U000F03D4'
source /usr/local/lib/sobarch/notify-user.sh

id=0
trap 'rc=$?; [[ $rc -eq 0 ]] || notify_user critical "sobarch: package install failed" \
    "Check: journalctl -u sobarch-firstboot-packages.service" "$id"; exit $rc' EXIT

mkdir -p "$(dirname "$MARKER")"

if [[ -s "$OFFICIAL_LIST" ]]; then
    mapfile -t packages <"$OFFICIAL_LIST"
    total=${#packages[@]}
    echo "sobarch-firstboot: installing $total selected package(s): ${packages[*]}"
    id=$(notify_user critical "sobarch: installing packages" "Installing $total selected package(s)..." 0 0)
    n=0
    for pkg in "${packages[@]}"; do
        id=$(notify_user critical "sobarch: installing packages" "Installing ($((n + 1))/$total): $pkg" "$id" $((n * 100 / total)))
        n=$((n + 1))
        pacman -S --needed --noconfirm "$pkg"
    done
    notify_user critical "sobarch: installing packages" "$total package(s) installed." "$id" 100 >/dev/null
else
    echo "sobarch-firstboot: no optional official-repo packages were selected."
fi

if [[ -s "$AUR_LIST" ]]; then
    mapfile -t aur_packages <"$AUR_LIST"
    echo "sobarch-firstboot: building/installing ${#aur_packages[@]} selected AUR package(s):" \
        "${aur_packages[*]}"
    # No percent hint here: aur-sync.sh builds this whole list as one
    # step with no incremental progress to report back, so a numeric
    # value would be a fabricated signal, not a real one.
    id=$(notify_user critical "sobarch: installing packages" "Building selected AUR package(s)..." "$id")
    /usr/local/lib/sobarch/aur-sync.sh "${aur_packages[@]}"
fi

touch "$MARKER"
