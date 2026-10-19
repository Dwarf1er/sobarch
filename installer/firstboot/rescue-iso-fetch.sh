#!/usr/bin/env bash
# Sourced, not run. Shared ISO fetch/extract logic for rescue-iso-setup.sh
# and refresh-rescue-iso.sh.

MIRROR_URL="https://geo.mirror.pkgbuild.com/iso/latest"

# sha256 of the ISO on the rescue partition. World-readable on purpose:
# sobarch-update-check.sh reads it as the logged-in user.
RESCUE_ISO_STAMP="/var/lib/sobarch/rescue-iso-sha256"

# Downloads and verifies the ISO in WORK_DIR (caller creates and removes it).
fetch_rescue_iso() {
    local work_dir="$1"

    curl -fL -o "$work_dir/archlinux-x86_64.iso" "$MIRROR_URL/archlinux-x86_64.iso"
    curl -fL -o "$work_dir/sha256sums.txt" "$MIRROR_URL/sha256sums.txt"

    ( cd "$work_dir" && grep 'archlinux-x86_64\.iso$' sha256sums.txt | sha256sum -c - )
}

# Copies the ISO's kernel/initramfs into WORK_DIR. Needs fetch_rescue_iso first.
extract_rescue_kernel() {
    local work_dir="$1" loop_mnt="$1/iso-mount"

    mkdir -p "$loop_mnt"
    mount -o loop,ro "$work_dir/archlinux-x86_64.iso" "$loop_mnt"
    cp "$loop_mnt/arch/boot/x86_64/vmlinuz-linux" "$work_dir/vmlinuz-linux"
    cp "$loop_mnt/arch/boot/x86_64/initramfs-linux.img" "$work_dir/initramfs-linux.img"
    umount "$loop_mnt"
}

# Call only after the ISO is written to the rescue media, so a failed write
# never records a release that didn't land.
record_rescue_iso_version() {
    local work_dir="$1"
    mkdir -p "$(dirname "$RESCUE_ISO_STAMP")"
    awk '/archlinux-x86_64\.iso$/{print $1; exit}' "$work_dir/sha256sums.txt" >"$RESCUE_ISO_STAMP"
    chmod 644 "$RESCUE_ISO_STAMP"
}
