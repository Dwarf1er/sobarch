#!/bin/bash
# Restore the root (@) subvolume to a previous Snapper snapshot.
#
# Must be run from OUTSIDE the running system: boot the official Arch
# ISO (or any rescue environment with btrfs-progs), not the installed
# system itself, since you cannot safely replace the @ subvolume you
# are currently running from. To find and verify the snapshot number
# you want first, boot into it directly via the GRUB menu entry
# grub-btrfsd already generates, that is read-only and
# non-destructive, then reboot back to the ISO to actually run this.
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
# Usage: snapshot-rollback.sh <device> <snapshot-number>
#   e.g. snapshot-rollback.sh /dev/nvme0n1p2 6
#
# <device> is the BTRFS partition (not the whole disk, not /dev/nvme0n1
# but its partition, e.g. /dev/nvme0n1p2), <snapshot-number> is the
# Snapper snapshot number, matching the directory name under
# @snapshots/ (visible via `snapper -c root list` on the installed
# system, or by inspecting @snapshots/ directly from this rescue
# context).

set -euo pipefail

DEVICE="${1:?Usage: snapshot-rollback.sh <device> <snapshot-number>}"
SNAPSHOT_NUM="${2:?Usage: snapshot-rollback.sh <device> <snapshot-number>}"
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
