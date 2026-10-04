#!/bin/bash
# Restore the root (@) subvolume to a previous Snapper snapshot.
#
# Disk encryption (Phase 22): rescue mode detects a LUKS-encrypted
# <device> (`cryptsetup isLuks`) and opens it interactively
# (`cryptsetup open`, prompting for the passphrase on the controlling
# tty) before mounting, then closes it again on exit. --online mode
# needs no such handling: findmnt already resolves to the mapper
# device on a system that's already unlocked and running.
#
# Two modes:
#
#   snapshot-rollback.sh <device> <snapshot-number>
#     Rescue mode: run from a live ISO (or any rescue environment with
#     btrfs-progs), when the installed system doesn't boot at all.
#     This is the only mode that always works, regardless of whether
#     the installed system can start.
#
#   snapshot-rollback.sh --online <snapshot-number>
#     Online mode: run directly on the currently booted, working
#     system, no live ISO needed. This is safe because `subvol=@` in
#     fstab is only resolved by name once, at mount time; the
#     currently-running system stays bound to its subvolume by
#     internal ID regardless of what the top-level directory entry
#     named "@" gets renamed to on a separate, secondary mount of the
#     same volume. The current session keeps running completely
#     unaffected either way; only the next boot picks up the change.
#     This is taken from https://github.com/hirak99/yabsnap as this
#     tool showed how to perform this.
#
# Both modes perform the same underlying operation (rename the current
# @, create a new writable @ from the chosen snapshot); only how the
# target device is determined, and whether an extra confirmation
# prompt applies, differs. A reboot is required afterward regardless
# of which mode was used.
#
# Implements the Arch Wiki's documented manual procedure, not `snapper
# rollback`, which the Wiki's own suggested filesystem layout (the
# @snapshots top-level subvolume this project also uses) is explicitly
# described as not intended to be used with:
# https://wiki.archlinux.org/title/Snapper#Restoring_/_to_its_previous_snapshot
#
# The previous @ is renamed, not deleted, so this is reversible if the
# chosen snapshot turns out to be wrong. Remove the renamed copy
# manually once you've confirmed the restore actually worked. This also
# means /var/log and the pacman cache (which live inside @, not their
# own subvolumes) aren't lost on rollback: they're still there under
# the renamed copy for as long as you keep it around.
#
# Usage:
#   snapshot-rollback.sh <device> <snapshot-number>
#     e.g. snapshot-rollback.sh /dev/nvme0n1p2 6
#   snapshot-rollback.sh --online [--yes] <snapshot-number>
#     e.g. snapshot-rollback.sh --online 6
#     --yes skips the typed confirmation, for callers with no
#     terminal (the snapshot-boot notification's click action, which
#     asks for confirmation in its own fuzzel prompt first).
#
# <device> is the BTRFS partition (not the whole disk, not /dev/nvme0n1
# but its partition, e.g. /dev/nvme0n1p2) -- or, on an encrypted
# install, the LUKS partition wrapping it; this script opens it for
# you. <snapshot-number> matches the directory name under @snapshots/
# (visible via `snapper -c root list` on the installed system, or by
# inspecting @snapshots/ directly from a rescue context once unlocked).

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

# Rescue mode only: --online's $DEVICE already came from findmnt on a
# live, unlocked system, so it's never itself a locked LUKS device
# (cryptsetup isLuks correctly says no and this is a no-op there).
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
# Extra mounts made inside the restored root while repairing /boot,
# unmounted (newest first) before the top-level mount itself.
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

# /boot (the ESP, outside every snapshot) still holds whatever kernel
# and initramfs were installed last. If the restored root predates a
# kernel upgrade, that kernel has no modules under the restored
# /usr/lib/modules, and the system boots without GPU, wifi, USB, etc.
# Put the restored root's own kernel back and rebuild its initramfs.
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
