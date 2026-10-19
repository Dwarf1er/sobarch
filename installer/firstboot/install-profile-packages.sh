#!/usr/bin/env bash
# Installs the optional profile packages selected in the TUI, on first boot
# once the network is up. MARKER stays unwritten on failure so it retries.

set -euo pipefail

SOBARCH_DIR="/etc/sobarch"
OFFICIAL_LIST="$SOBARCH_DIR/profile-packages-official.txt"
AUR_LIST="$SOBARCH_DIR/profile-packages-aur.txt"
MARKER="/var/lib/sobarch/profile-packages-installed"

# md-package_down
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
# One transaction for the whole list: per-package calls would each take a
# snap-pac snapshot pair.
    id=$(notify_user critical "sobarch: installing packages" "Installing $total selected package(s)..." 0)
    pacman -S --needed --noconfirm "${packages[@]}"
    notify_user critical "sobarch: installing packages" "$total package(s) installed." "$id" 100 >/dev/null
else
    echo "sobarch-firstboot: no optional official-repo packages were selected."
fi

if [[ -s "$AUR_LIST" ]]; then
    mapfile -t aur_packages <"$AUR_LIST"
    echo "sobarch-firstboot: building/installing ${#aur_packages[@]} selected AUR package(s):" \
        "${aur_packages[*]}"
    id=$(notify_user critical "sobarch: installing packages" "Building selected AUR package(s)..." "$id")
    /usr/local/lib/sobarch/aur-sync.sh "${aur_packages[@]}"
fi

touch "$MARKER"
