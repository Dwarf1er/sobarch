#!/usr/bin/env bash
# Privileged worker behind Sobarch -> Refresh Rescue ISO
# (skel/.config/hypr/scripts/refresh-rescue-menu.sh), run via
# pkexec. Re-fetches a current Arch ISO and re-extracts its
# kernel/initramfs onto the two rescue partitions
# installer/archinstall/rescue-iso-setup.sh laid out at install time
# (RESCUE: the .iso itself; RESCUEBOOT: vmlinuz-linux/
# initramfs-linux.img), overwriting their content in place. No mkfs,
# no partition-table change, no limine.conf edit: both partitions and
# the UUID/PARTUUID rescue-iso-setup.sh's Limine entry already
# addresses them by are untouched, so that entry keeps working against
# the refreshed files with nothing else to update.
#
# Found by filesystem label, not a device path: unlike
# rescue-iso-setup.sh (a TUI-driven install-time step with
# RESCUE_PARTITION/RESCUE_BOOT_PARTITION passed in as env vars), this
# runs standalone against an already-installed system with no such
# input available. rescue-iso-setup.sh labels them RESCUE/RESCUEBOOT
# specifically so this script can find them again later.

set -euo pipefail

source /usr/local/lib/sobarch/rescue-iso-fetch.sh
source /usr/local/lib/sobarch/durable-replace.sh

# Runs as root via pkexec, same as the first-boot units notify-user.sh
# was written for: a desktop notification back into the invoking user's
# session needs the same runuser dance, not just an echo to a log
# nobody's watching mid-refresh. 󰑐 (nf-md-refresh) matches
# setup-menu.sh's own "Refresh Rescue ISO" entry icon. Success/failure
# themselves stay refresh-rescue-menu.sh's job (it already reports
# both once pkexec returns); these are just the in-progress steps of
# what is otherwise a silent multi-minute download+write with nothing
# to show for it until the very end.
GLYPH=$'\U000F0450'
source /usr/local/lib/sobarch/notify-user.sh

RESCUE_DEV="$(blkid -L RESCUE)" || {
    echo "refresh-rescue-iso: no RESCUE partition found (rescue media opted out at install time?), nothing to do."
    exit 0
}
RESCUE_BOOT_DEV="$(blkid -L RESCUEBOOT)" || {
    echo "refresh-rescue-iso: RESCUE partition found but RESCUEBOOT is missing; refusing to proceed with a half rescue setup." >&2
    exit 1
}

WORK_DIR=$(mktemp -d)
RESCUE_MNT="$WORK_DIR/rescue"
RESCUE_BOOT_MNT="$WORK_DIR/rescue-boot"
cleanup() {
    umount "$RESCUE_MNT" 2>/dev/null || true
    umount "$RESCUE_BOOT_MNT" 2>/dev/null || true
    umount "$WORK_DIR/iso-mount" 2>/dev/null || true
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

echo "refresh-rescue-iso: fetching current Arch ISO from $MIRROR_URL..."
id=$(notify_user normal "sobarch: refresh rescue iso" "Fetching current Arch ISO from $MIRROR_URL...")
fetch_rescue_iso "$WORK_DIR"

echo "refresh-rescue-iso: extracting the ISO's own kernel/initramfs..."
id=$(notify_user normal "sobarch: refresh rescue iso" "Extracting the ISO's own kernel/initramfs..." "$id")
extract_rescue_kernel "$WORK_DIR"

echo "refresh-rescue-iso: writing the refreshed ISO to $RESCUE_DEV..."
id=$(notify_user normal "sobarch: refresh rescue iso" "Writing the refreshed ISO to $RESCUE_DEV..." "$id")
mkdir -p "$RESCUE_MNT"
mount "$RESCUE_DEV" "$RESCUE_MNT"
# durable_replace, not a plain cp: the same crash-safety this project
# already needed for apply-skel.sh's reconciliation (a real run once
# died mid-write and left touched files zero-length on reboot) applies
# just as much to overwriting the one file img_dev=/img_loop= loop-mounts
# at boot. Both partitions have room to spare for the temp copy this
# needs (5GiB RESCUE against a ~1.3GB ISO).
durable_replace 644 "$WORK_DIR/archlinux-x86_64.iso" "$RESCUE_MNT/archlinux-x86_64.iso"
umount "$RESCUE_MNT"

echo "refresh-rescue-iso: writing the refreshed kernel/initramfs to $RESCUE_BOOT_DEV..."
id=$(notify_user normal "sobarch: refresh rescue iso" "Writing the refreshed kernel/initramfs to $RESCUE_BOOT_DEV..." "$id")
mkdir -p "$RESCUE_BOOT_MNT"
mount "$RESCUE_BOOT_DEV" "$RESCUE_BOOT_MNT"
durable_replace 644 "$WORK_DIR/vmlinuz-linux" "$RESCUE_BOOT_MNT/vmlinuz-linux"
durable_replace 644 "$WORK_DIR/initramfs-linux.img" "$RESCUE_BOOT_MNT/initramfs-linux.img"
umount "$RESCUE_BOOT_MNT"

echo "refresh-rescue-iso: done."
