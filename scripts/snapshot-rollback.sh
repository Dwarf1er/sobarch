#!/bin/bash
# Restores the root (@) subvolume from a Snapper snapshot, following the
# Arch Wiki's manual procedure rather than `snapper rollback`:
# https://wiki.archlinux.org/title/Snapper#Restoring_/_to_its_previous_snapshot
#
# Usage:
#   snapshot-rollback.sh <device> <snapshot-number>
#     Rescue mode, from a live ISO. <device> is the BTRFS partition, or
#     the LUKS partition wrapping it (unlocked interactively).
#   snapshot-rollback.sh --online [--yes] <snapshot-number>
#     On the running system. The mounted @ is bound by subvolume ID, so
#     renaming it doesn't affect the current session (approach from
#     https://github.com/hirak99/yabsnap). --yes skips the confirmation.
#
# The old @ is renamed, not deleted, so the restore is reversible. A
# reboot is required afterward.

set -euo pipefail

ASSUME_YES=false
if [ "${1:-}" = "--online" ]; then
    ONLINE=true
    shift
    if [ "${1:-}" = "--yes" ]; then
        ASSUME_YES=true
        shift
    fi
    SNAPSHOT_NUM="${1:?Usage: snapshot-rollback.sh --online [--yes] <snapshot-number>}"
    DEVICE=$(findmnt -n -o SOURCE / | sed 's/\[.*//')
    if [ -z "$DEVICE" ]; then
        echo "error: could not determine the root device from findmnt" >&2
        exit 1
    fi
else
    ONLINE=false
    DEVICE="${1:?Usage: snapshot-rollback.sh <device> <snapshot-number>, or --online <snapshot-number>}"
    SNAPSHOT_NUM="${2:?Usage: snapshot-rollback.sh <device> <snapshot-number>, or --online <snapshot-number>}"
fi

if [ "$ONLINE" = true ] && [ "$ASSUME_YES" = false ]; then
    echo "This will restore @ from snapshot $SNAPSHOT_NUM on the currently"
    echo "running system ($DEVICE). The current session keeps running"
    echo "unaffected; the change only takes effect after a reboot, which is"
    echo "required either way."
    read -r -p "Type YES to proceed: " confirm
    if [ "$confirm" != "YES" ]; then
        echo "Aborted." >&2
        exit 1
    fi
fi

# Rescue mode only: --online's device is already unlocked.
MOUNT_DEVICE="$DEVICE"
LUKS_MAPPER_NAME="sobarch-rollback"
LUKS_OPENED_HERE=false
if [ "$ONLINE" = false ] && cryptsetup isLuks "$DEVICE"; then
    if cryptsetup status "$LUKS_MAPPER_NAME" >/dev/null 2>&1; then
        echo "$LUKS_MAPPER_NAME is already open, reusing it."
    else
        echo "$DEVICE is LUKS-encrypted; enter its passphrase to unlock it."
        cryptsetup open "$DEVICE" "$LUKS_MAPPER_NAME"
        LUKS_OPENED_HERE=true
    fi
    MOUNT_DEVICE="/dev/mapper/$LUKS_MAPPER_NAME"
fi

MOUNT_POINT=$(mktemp -d)
# Mounts made under the restored root, unmounted newest first.
EXTRA_MOUNTS=()
cleanup() {
    for ((i = ${#EXTRA_MOUNTS[@]} - 1; i >= 0; i--)); do
        umount -R "${EXTRA_MOUNTS[$i]}" 2>/dev/null || true
    done
    umount "$MOUNT_POINT" 2>/dev/null || true
    rmdir "$MOUNT_POINT" 2>/dev/null || true
    if [ "$LUKS_OPENED_HERE" = true ]; then
        cryptsetup close "$LUKS_MAPPER_NAME" 2>/dev/null || true
    fi
}
trap cleanup EXIT

echo "Mounting the top-level subvolume (subvolid=5) from $MOUNT_DEVICE..."
mount -o subvolid=5 "$MOUNT_DEVICE" "$MOUNT_POINT"

SNAPSHOT_SRC="$MOUNT_POINT/@snapshots/$SNAPSHOT_NUM/snapshot"
if [ ! -d "$SNAPSHOT_SRC" ]; then
    echo "error: no snapshot found at $SNAPSHOT_SRC" >&2
    exit 1
fi

BROKEN_BACKUP=""
if [ -d "$MOUNT_POINT/@" ]; then
    BROKEN_BACKUP="@.broken.$(date +%Y%m%d%H%M%S)"
    echo "Renaming the current @ to $BROKEN_BACKUP (not deleting it)..."
    mv "$MOUNT_POINT/@" "$MOUNT_POINT/$BROKEN_BACKUP"
fi

echo "Creating a new writable @ from snapshot $SNAPSHOT_NUM..."
btrfs subvolume snapshot "$SNAPSHOT_SRC" "$MOUNT_POINT/@"

# /boot is outside every snapshot, so its kernel may not match the
# restored root's modules. Restore that kernel and rebuild the initramfs.
repair_boot_kernel() {
    local new_root="$MOUNT_POINT/@" version="" dir
    for dir in "$new_root"/usr/lib/modules/*/; do
        [ -f "${dir}pkgbase" ] && [ "$(cat "${dir}pkgbase")" = "linux" ] || continue
        version="$(basename "$dir")"
    done
    if [ -z "$version" ]; then
        echo "warning: no linux kernel found in the restored root; /boot left as is." >&2
        return 1
    fi

    local esp=""
    if [ "$ONLINE" = true ]; then
        esp="$(findmnt -n -o SOURCE /boot | sed 's/\[.*//')"
    else
        local disk
        disk="$(lsblk -no PKNAME "$DEVICE" 2>/dev/null | head -n1)"
        [ -n "$disk" ] && esp="$(lsblk -rnpo PATH,PARTTYPE "/dev/$disk" | awk 'tolower($2) == "c12a7328-f81f-11d2-ba4b-00a0c93ec93b" {print $1; exit}')"
    fi
    if [ -z "$esp" ]; then
        echo "warning: could not locate the EFI System Partition; /boot left as is." >&2
        return 1
    fi

    mount "$esp" "$new_root/boot" || return 1
    EXTRA_MOUNTS+=("$new_root/boot")

    if cmp -s "$new_root/usr/lib/modules/$version/vmlinuz" "$new_root/boot/vmlinuz-linux"; then
        echo "/boot already holds the restored root's kernel ($version)."
        return 0
    fi

    echo "Restoring the kernel and initramfs for $version into /boot..."
    install -m644 "$new_root/usr/lib/modules/$version/vmlinuz" "$new_root/boot/vmlinuz-linux" || return 1
    local sub
    for sub in dev proc sys; do
        mount --rbind "/$sub" "$new_root/$sub" || return 1
        EXTRA_MOUNTS+=("$new_root/$sub")
    done
    chroot "$new_root" mkinitcpio -P
}

echo "Checking that /boot matches the restored system's kernel..."
if ! repair_boot_kernel; then
    echo "warning: /boot was NOT updated to match the restored system. If it fails to boot" >&2
    echo "         properly, reinstall the kernel from a chroot into the restored @." >&2
fi

echo
echo "Done. @ has been restored from snapshot $SNAPSHOT_NUM."
if [ -n "$BROKEN_BACKUP" ]; then
    echo "The previous @ was renamed to $BROKEN_BACKUP, not deleted."
    echo "Once you've confirmed the restore worked, remove it manually with:"
    echo "  btrfs subvolume delete <mountpoint>/$BROKEN_BACKUP"
fi
echo "Reboot now to use the restored system."
