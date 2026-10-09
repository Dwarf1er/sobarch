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
# Install time only formats and labels the media. The ~1.3GB ISO
# download, the write, and the Limine entry are deferred to first boot
# (installer/firstboot/setup-rescue-iso.sh, started by the NetworkManager
# dispatcher like the other network-dependent units), so the install
# itself never blocks on that download. The ISO is fetched over the
# network rather than copied from the live boot medium: a copy would
# silently carry over whatever version happened to be used for install
# day one, and a live USB written with `dd` has no filesystem
# archinstall (or this script) could mount to read the ISO back out of
# anyway.

set -euo pipefail

if [ -z "${RESCUE_PARTITION:-}" ]; then
    echo "rescue-iso-setup.sh: RESCUE_PARTITION not set (rescue media opted out), nothing to do."
    exit 0
fi
if [ -z "${RESCUE_BOOT_PARTITION:-}" ] && [ "${RESCUE_BOOT_MERGED:-}" != "true" ]; then
    echo "rescue-iso-setup.sh: neither RESCUE_BOOT_PARTITION nor RESCUE_BOOT_MERGED set, nothing to do."
    exit 0
fi

mkfs.ext4 -F -L RESCUE "$RESCUE_PARTITION"

if [ -n "${RESCUE_BOOT_PARTITION:-}" ]; then
    # mkfs.fat needs dosfstools in the target's own package list
    # (base.json): the live ISO always has it, but archinstall formats
    # the ESP itself before pacstrap even runs, using the live
    # environment's own tools, so the target was never otherwise
    # required to carry it. This script is the first thing that needs
    # mkfs.fat inside the already-installed target (arch-chroot, after
    # pacstrap).
    mkfs.fat -F32 -n RESCUEBOOT "$RESCUE_BOOT_PARTITION"
else
    mkdir -p /boot/rescue
fi

# Read by sobarch-firstboot-rescue.service's ConditionPathExists;
# setup-rescue-iso.sh removes it once the ISO has actually landed.
mkdir -p /etc/sobarch
touch /etc/sobarch/rescue-pending

echo "rescue-iso-setup.sh: done (ISO download deferred to first boot)."
