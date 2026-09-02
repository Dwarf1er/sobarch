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

mkdir -p "$(dirname "$MARKER")"

if [[ -s "$OFFICIAL_LIST" ]]; then
    mapfile -t packages <"$OFFICIAL_LIST"
    echo "sobarch-firstboot: installing ${#packages[@]} selected package(s): ${packages[*]}"
    pacman -S --needed --noconfirm "${packages[@]}"
else
    echo "sobarch-firstboot: no optional official-repo packages were selected."
fi

if [[ -s "$AUR_LIST" ]]; then
    echo "sobarch-firstboot: the following selected AUR package(s) were NOT installed" \
        "(packages/aur/ vendoring isn't implemented yet):"
    cat "$AUR_LIST"
fi

touch "$MARKER"
