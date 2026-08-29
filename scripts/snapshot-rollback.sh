#!/bin/bash
# Restore the root (@) subvolume to a previous Snapper snapshot.
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
# manually once you've confirmed the restore actually worked.
#
# Usage:
#   snapshot-rollback.sh <device> <snapshot-number>
#     e.g. snapshot-rollback.sh /dev/nvme0n1p2 6
#   snapshot-rollback.sh --online <snapshot-number>
#     e.g. snapshot-rollback.sh --online 6
#
# <device> is the BTRFS partition (not the whole disk, not /dev/nvme0n1
# but its partition, e.g. /dev/nvme0n1p2). <snapshot-number> matches
# the directory name under @snapshots/ (visible via `snapper -c root
# list` on the installed system, or by inspecting @snapshots/ directly
# from a rescue context).

set -euo pipefail

if [ "${1:-}" = "--online" ]; then
    ONLINE=true
    SNAPSHOT_NUM="${2:?Usage: snapshot-rollback.sh --online <snapshot-number>}"
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

if [ "$ONLINE" = true ]; then
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

MOUNT_POINT=$(mktemp -d)
cleanup() {
    umount "$MOUNT_POINT" 2>/dev/null || true
    rmdir "$MOUNT_POINT" 2>/dev/null || true
}
trap cleanup EXIT

echo "Mounting the top-level subvolume (subvolid=5) from $DEVICE..."
mount -o subvolid=5 "$DEVICE" "$MOUNT_POINT"

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

echo
echo "Done. @ has been restored from snapshot $SNAPSHOT_NUM."
if [ -n "$BROKEN_BACKUP" ]; then
    echo "The previous @ was renamed to $BROKEN_BACKUP, not deleted."
    echo "Once you've confirmed the restore worked, remove it manually with:"
    echo "  btrfs subvolume delete <mountpoint>/$BROKEN_BACKUP"
fi
echo "Reboot now to use the restored system."
