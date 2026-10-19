#!/bin/bash
# Configures Snapper for root only, with @snapshots mounted at /.snapshots.
#
# snapper create-config refuses to run when /.snapshots already exists, so when
# archinstall didn't create the root config we let it make a nested subvolume,
# delete that, and remount @snapshots (Arch Wiki Snapper#Suggested_filesystem_layout).
# archinstall's auto-created home config is deleted: it would nest .snapshots in @home.

set -euo pipefail

if ! mountpoint -q /.snapshots; then
    echo "error: /.snapshots is not a separate mounted subvolume; refusing to continue (would nest .snapshots inside @)" >&2
    exit 1
fi

existing_configs="$(snapper --no-dbus list-configs | awk '{print $1}')"

if grep -qx home <<<"$existing_configs"; then
    echo "snapper-setup.sh: deleting the auto-created 'home' Snapper config (snapshots are root-only)..."
    snapper --no-dbus -c home delete-config
else
    echo "snapper-setup.sh: no 'home' Snapper config was created, nothing to delete."
fi

if ! grep -qx root <<<"$existing_configs"; then
    echo "snapper-setup.sh: no 'root' Snapper config was created by archinstall; creating it..."
    # create-config fails if /.snapshots exists at all, even as an empty directory.
    umount /.snapshots
    rmdir /.snapshots
    snapper --no-dbus -c root create-config /
    btrfs subvolume delete /.snapshots
    mkdir /.snapshots
    mount /.snapshots
    chmod 750 /.snapshots
fi

echo "snapper-setup.sh: applying retention preset (daily, 5 kept) to root..."

# NUMBER_LIMIT is kept low because the pacman cache lives inside @ and old
# snapshots pin it.
sed -i \
    -e 's/^TIMELINE_LIMIT_HOURLY=.*/TIMELINE_LIMIT_HOURLY="0"/' \
    -e 's/^TIMELINE_LIMIT_DAILY=.*/TIMELINE_LIMIT_DAILY="5"/' \
    -e 's/^TIMELINE_LIMIT_WEEKLY=.*/TIMELINE_LIMIT_WEEKLY="0"/' \
    -e 's/^TIMELINE_LIMIT_MONTHLY=.*/TIMELINE_LIMIT_MONTHLY="0"/' \
    -e 's/^TIMELINE_LIMIT_YEARLY=.*/TIMELINE_LIMIT_YEARLY="0"/' \
    -e 's/^NUMBER_LIMIT=.*/NUMBER_LIMIT="5"/' \
    -e 's/^NUMBER_LIMIT_IMPORTANT=.*/NUMBER_LIMIT_IMPORTANT="5"/' \
    /etc/snapper/configs/root

echo "snapper-setup.sh: creating initial snapshot..."

snapper --no-dbus -c root create --description "Initial system setup"

echo "snapper-setup.sh: enabling sobarch-limine-snapshotd..."

systemctl enable --now sobarch-limine-snapshotd.service

echo "snapper-setup.sh: seeding the Limine snapshot menu for the initial snapshot..."

sobarch-limine-snapshot-sync

echo "snapper-setup.sh: done."
