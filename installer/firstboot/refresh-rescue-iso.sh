#!/usr/bin/env bash
# Privileged worker behind Sobarch -> Refresh Rescue ISO, run via pkexec.
# Overwrites the ISO and kernel/initramfs on the existing rescue media in
# place, so the Limine entry keeps working unchanged. Partitions are found by
# label since no device paths are available after install.

set -euo pipefail

source /usr/local/lib/sobarch/rescue-iso-fetch.sh
source /usr/local/lib/sobarch/durable-replace.sh

# nf-md-usb_flash_drive. Success/failure is reported by refresh-rescue-menu.sh.
GLYPH="󱊞"
source /usr/local/lib/sobarch/notify-user.sh

RESCUE_DEV="$(blkid -L RESCUE)" || {
    echo "refresh-rescue-iso: no RESCUE partition found (rescue media opted out at install time?), nothing to do."
    exit 0
}

RESCUE_BOOT_DEV=""
if [ -d /sys/firmware/efi ]; then
    RESCUE_BOOT_DEV="$(blkid -L RESCUEBOOT)" || {
        echo "refresh-rescue-iso: RESCUE partition found but RESCUEBOOT is missing; refusing to proceed with a half rescue setup." >&2
        exit 1
    }
    RESCUE_BOOT_DEST="$RESCUE_BOOT_DEV"
else
    [ -d /boot/rescue ] || {
        echo "refresh-rescue-iso: RESCUE partition found but /boot/rescue is missing; refusing to proceed with a half rescue setup." >&2
        exit 1
    }
    RESCUE_BOOT_DEST="/boot/rescue"
fi

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
# Crash-safe: this is the file img_loop= loop-mounts at boot.
durable_replace 644 "$WORK_DIR/archlinux-x86_64.iso" "$RESCUE_MNT/archlinux-x86_64.iso"
umount "$RESCUE_MNT"

echo "refresh-rescue-iso: writing the refreshed kernel/initramfs to $RESCUE_BOOT_DEST..."
id=$(notify_user normal "sobarch: refresh rescue iso" "Writing the refreshed kernel/initramfs to $RESCUE_BOOT_DEST..." "$id")
if [ -n "$RESCUE_BOOT_DEV" ]; then
    mkdir -p "$RESCUE_BOOT_MNT"
    mount "$RESCUE_BOOT_DEV" "$RESCUE_BOOT_MNT"
    durable_replace 644 "$WORK_DIR/vmlinuz-linux" "$RESCUE_BOOT_MNT/vmlinuz-linux"
    durable_replace 644 "$WORK_DIR/initramfs-linux.img" "$RESCUE_BOOT_MNT/initramfs-linux.img"
    umount "$RESCUE_BOOT_MNT"
else
    durable_replace 644 "$WORK_DIR/vmlinuz-linux" "$RESCUE_BOOT_DEST/vmlinuz-linux"
    durable_replace 644 "$WORK_DIR/initramfs-linux.img" "$RESCUE_BOOT_DEST/initramfs-linux.img"
fi

record_rescue_iso_version "$WORK_DIR"

echo "refresh-rescue-iso: done."
