#!/bin/bash
# Rescue media population, run by the TUI as the same post-archinstall,
# pre-reboot arch-chroot step as nvidia-setup.sh/snapper-setup.sh.
#
# base.json's disk_config reserves a dedicated ext4 partition
# (unformatted by archinstall, no mountpoint) specifically so
# scripts/snapshot-rollback.sh's rescue mode has a full Arch ISO
# available on local disk, no separate USB device needed at all. This
# is opt-out: the TUI removes this partition entirely (shifting the
# BTRFS partition's start back down to 1025 MiB) when the user
# declines it for disk space reasons, in which case RESCUE_PARTITION
# below is unset and this script is skipped.
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

MIRROR_URL="https://geo.mirror.pkgbuild.com/iso/latest"
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

echo "rescue-iso-setup.sh: fetching current Arch ISO from $MIRROR_URL..."

curl -fL -o "$WORK_DIR/archlinux-x86_64.iso" "$MIRROR_URL/archlinux-x86_64.iso"
curl -fL -o "$WORK_DIR/sha256sums.txt" "$MIRROR_URL/sha256sums.txt"

echo "rescue-iso-setup.sh: verifying checksum..."

( cd "$WORK_DIR" && grep 'archlinux-x86_64\.iso$' sha256sums.txt | sha256sum -c - )

echo "rescue-iso-setup.sh: formatting $RESCUE_PARTITION and writing the ISO..."

mkfs.ext4 -F -L RESCUE "$RESCUE_PARTITION"
mount "$RESCUE_PARTITION" /mnt
cp "$WORK_DIR/archlinux-x86_64.iso" /mnt/archlinux-x86_64.iso
RESCUE_UUID=$(blkid -s UUID -o value "$RESCUE_PARTITION")
umount /mnt

echo "rescue-iso-setup.sh: adding the GRUB boot entry..."

# Every monthly Arch ISO carries its own /boot/grub/loopback.cfg, built and shipped for exactly this scenario
mkdir -p /etc/grub.d
cat > /etc/grub.d/41_rescue_iso <<EOF
#!/bin/sh
exec tail -n +3 \$0
menuentry "Arch Linux rescue (local ISO)" {
    insmod part_gpt
    insmod ext2
    set iso_path="/archlinux-x86_64.iso"
    search --no-floppy --fs-uuid --set=isopart $RESCUE_UUID
    loopback loop (\$isopart)\$iso_path
    root=(loop)
    configfile /boot/grub/loopback.cfg
    loopback --delete loop
}
EOF
chmod 755 /etc/grub.d/41_rescue_iso

grub-mkconfig -o /boot/grub/grub.cfg

echo "rescue-iso-setup.sh: done."
