#!/bin/bash
# Rescue media population, run by the TUI as the same post-archinstall,
# pre-reboot arch-chroot step as nvidia-setup.sh/snapper-setup.sh.
#
# base.json's disk_config reserves one or two dedicated partitions for
# this (two on UEFI, one on BIOS -- see below), unformatted by
# archinstall (no mountpoint), specifically so
# scripts/snapshot-rollback.sh's rescue mode has a full Arch ISO
# available on local disk, no separate USB device needed at all. Opt-out
# is all-or-nothing: the TUI removes them entirely (shifting the BTRFS
# partition's start back down) when the user declines rescue media for
# disk space reasons, in which case RESCUE_PARTITION below is unset and
# this script is skipped.
#
# Split in two, Ventoy-style, because Limine can't read
# ext4 and has no GRUB-style `loopback` command to read an ISO9660 file
# as a virtual device:
#   - RESCUE_PARTITION (ext4): holds the fetched .iso itself, as a
#     plain file. This is the piece that must stay a plain,
#     dd-free, overwrite-to-refresh file: FAT32's 4GB per-file cap
#     (documented plainly by Ventoy, which keeps large ISO payloads off
#     FAT32 for exactly this reason) is a real, live constraint an Arch
#     ISO could plausibly outgrow over the life of this project, so the
#     potentially-large payload deliberately stays off FAT32 entirely.
#   - RESCUE_BOOT_PARTITION (fat32): holds only the small
#     vmlinuz-linux/initramfs-linux.img extracted from inside that ISO
#     (~100MB total), on a filesystem Limine can actually read to boot
#     them. Refreshing later is still just re-extracting these two
#     files plus overwriting the .iso -- no dd, no raw partition
#     flashing, on either partition.
#
# On a BIOS install, RESCUE_BOOT_PARTITION doesn't exist: archinstall
# picks MBR for BIOS (GPT for UEFI), and MBR is capped at 3 primary
# partitions -- one over budget with boot+rescue-boot+rescue+root all
# primary. config_gen.py drops the dedicated rescue-boot partition in
# that case (RESCUE_BOOT_MERGED=true instead) and this script writes
# the extracted kernel/initramfs straight into /boot/rescue/, which is
# already the target's own FAT32 boot partition -- no separate
# mkfs/mount needed for it at all, since /boot is already mounted here.
# The archiso initramfs's own img_dev=/img_loop= mechanism (which finds
# and loop-mounts the .iso at boot) is implemented in mkinitcpio-archiso's
# own hook, running in early userspace under the kernel Limine already
# booted, with no filesystem-type assumption -- so it works identically
# regardless of which bootloader got the kernel running in the first
# place.
#
# Populated by fetching a fresh ISO over the network rather than
# copying the live boot medium's own ISO file: a copy would silently
# carry over whatever version happened to be used for install day one,
# and a live USB written with `dd` has no filesystem archinstall (or
# this script) could mount to read the ISO back out of anyway.

set -euo pipefail

if [ -z "${RESCUE_PARTITION:-}" ]; then
    echo "rescue-iso-setup.sh: RESCUE_PARTITION not set (rescue media opted out), nothing to do."
    exit 0
fi
if [ -z "${RESCUE_BOOT_PARTITION:-}" ] && [ "${RESCUE_BOOT_MERGED:-}" != "true" ]; then
    echo "rescue-iso-setup.sh: neither RESCUE_BOOT_PARTITION nor RESCUE_BOOT_MERGED set, nothing to do."
    exit 0
fi

# Shared with refresh-rescue-iso.sh (installer/firstboot/
# rescue-iso-fetch.sh): fetch/verify/extract is the same logic either
# way, only what's done with the result differs. Already installed by
# the time this script runs: install_runner.py builds and installs
# sobarch-scripts before running any CHROOT_SETUP_SCRIPTS.
source /usr/local/lib/sobarch/rescue-iso-fetch.sh

WORK_DIR=$(mktemp -d)
trap 'umount "$WORK_DIR/iso-mount" 2>/dev/null || true; rm -rf "$WORK_DIR"' EXIT

echo "rescue-iso-setup.sh: fetching current Arch ISO from $MIRROR_URL..."
fetch_rescue_iso "$WORK_DIR"

echo "rescue-iso-setup.sh: extracting the ISO's own kernel/initramfs..."
extract_rescue_kernel "$WORK_DIR"

echo "rescue-iso-setup.sh: formatting $RESCUE_PARTITION and writing the ISO..."

mkfs.ext4 -F -L RESCUE "$RESCUE_PARTITION"
mount "$RESCUE_PARTITION" /mnt
cp "$WORK_DIR/archlinux-x86_64.iso" /mnt/archlinux-x86_64.iso
RESCUE_UUID=$(blkid -s UUID -o value "$RESCUE_PARTITION")
umount /mnt

if [ -n "${RESCUE_BOOT_PARTITION:-}" ]; then
    echo "rescue-iso-setup.sh: formatting $RESCUE_BOOT_PARTITION and writing the extracted kernel/initramfs..."

    # mkfs.fat needs dosfstools in the target's own package list
    # (base.json): the live ISO always has it, but archinstall formats
    # the ESP itself before pacstrap even runs, using the live
    # environment's own tools, so the target was never otherwise
    # required to carry it. This script is the first thing that needs
    # mkfs.fat inside the already-installed target (arch-chroot, after
    # pacstrap).
    mkfs.fat -F32 -n RESCUEBOOT "$RESCUE_BOOT_PARTITION"
    mount "$RESCUE_BOOT_PARTITION" /mnt
    cp "$WORK_DIR/vmlinuz-linux" /mnt/vmlinuz-linux
    cp "$WORK_DIR/initramfs-linux.img" /mnt/initramfs-linux.img
    # Limine's guid()/uuid() path resolver matches a filesystem UUID or
    # a GPT partition GUID, both full 128-bit values -- never FAT32's
    # own "UUID" (blkid -s UUID here), which is really just its short
    # 32-bit volume serial number (e.g. 1B83-B836) and never matches.
    # The partition's own GPT PARTUUID is the one identifier FAT32
    # actually has that fits.
    RESCUE_BOOT_PARTUUID=$(blkid -s PARTUUID -o value "$RESCUE_BOOT_PARTITION")
    umount /mnt
    KERNEL_PATH="uuid(${RESCUE_BOOT_PARTUUID}):/vmlinuz-linux"
    INITRD_PATH="uuid(${RESCUE_BOOT_PARTUUID}):/initramfs-linux.img"
else
    echo "rescue-iso-setup.sh: writing the extracted kernel/initramfs into /boot/rescue..."
    mkdir -p /boot/rescue
    cp "$WORK_DIR/vmlinuz-linux" /boot/rescue/vmlinuz-linux
    cp "$WORK_DIR/initramfs-linux.img" /boot/rescue/initramfs-linux.img
    KERNEL_PATH="boot():/rescue/vmlinuz-linux"
    INITRD_PATH="boot():/rescue/initramfs-linux.img"
fi

echo "rescue-iso-setup.sh: adding the Limine boot entry..."

# Same has_uefi() check archinstall's own _add_limine_bootloader() makes
# to decide where it writes limine.conf: EFI/BOOT on the ESP when UEFI,
# /boot/limine otherwise (see limine-theme-setup.sh's own copy of this
# check for the full rationale).
if [ -d /sys/firmware/efi ]; then
    LIMINE_CONF="/boot/EFI/BOOT/limine.conf"
else
    LIMINE_CONF="/boot/limine/limine.conf"
fi
START_MARKER="#### SOBARCH RESCUE ENTRY START (auto-generated by rescue-iso-setup.sh, do not edit by hand)"
END_MARKER="#### SOBARCH RESCUE ENTRY END"

# Own delimited block, distinct from sobarch-limine-snapshot-sync's own
# "SOBARCH SNAPSHOTS" block, so the two never clobber each other or
# archinstall's own base OS entry when either regenerates.
block="$START_MARKER
/Arch Linux rescue (local ISO)
    protocol: linux
    path: ${KERNEL_PATH}
    module_path: ${INITRD_PATH}
    cmdline: archisobasedir=arch img_dev=UUID=${RESCUE_UUID} img_loop=/archlinux-x86_64.iso
$END_MARKER"

if grep -qF "$START_MARKER" "$LIMINE_CONF"; then
    awk -v start="$START_MARKER" -v end="$END_MARKER" -v block="$block" '
        $0 == start { print block; skipping = 1; next }
        $0 == end && skipping { skipping = 0; next }
        skipping { next }
        { print }
    ' "$LIMINE_CONF" > "${LIMINE_CONF}.sobarch-new"
    mv "${LIMINE_CONF}.sobarch-new" "$LIMINE_CONF"
else
    printf '\n%s\n' "$block" >> "$LIMINE_CONF"
fi

echo "rescue-iso-setup.sh: done."
