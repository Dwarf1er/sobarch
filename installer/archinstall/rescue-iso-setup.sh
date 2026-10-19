#!/bin/bash
# Formats the rescue media partitions. The ISO download and Limine entry happen
# at first boot (installer/firstboot/setup-rescue-iso.sh).
#
# The ISO goes on ext4 (it may outgrow FAT32's 4GB file limit), and its extracted
# kernel/initramfs on FAT32 so Limine can boot them. On BIOS/MBR there is no room
# for a separate rescue-boot partition, so those go in /boot/rescue instead.

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
    # Requires dosfstools in base.json's package list; archinstall formats the ESP from the live ISO.
    mkfs.fat -F32 -n RESCUEBOOT "$RESCUE_BOOT_PARTITION"
else
    mkdir -p /boot/rescue
fi

# Gates sobarch-firstboot-rescue.service; removed once the ISO is in place.
mkdir -p /etc/sobarch
touch /etc/sobarch/rescue-pending

echo "rescue-iso-setup.sh: done (ISO download deferred to first boot)."
