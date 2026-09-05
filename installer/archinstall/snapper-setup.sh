#!/bin/bash
# Snapper retention preset, run by the TUI as the same
# post-archinstall, pre-reboot arch-chroot step as nvidia-setup.sh.
#
# `@snapshots` (base.json's disk_config) is what makes this safe to run
# at all: it's already mounted at /.snapshots as its own top-level
# BTRFS subvolume before this runs. This is the Arch Wiki's own
# documented fix for a well-known problem with the flat
# Arch-recommended layout: if `.snapshots` lives inside `@`, replacing
# `@` during a rollback wipes the snapshot history out along with it.
# (https://wiki.archlinux.org/title/Snapper#Suggested_filesystem_layout)
#
# `snapper create-config` does NOT auto-detect and reuse an
# already-mounted `.snapshots` subvolume the way that Wiki section's
# prose might suggest: it unconditionally tries to create the
# `.snapshots` subvolume itself and fails outright (btrfs EEXIST) when
# something is already mounted there. So, matching the same Wiki
# section's actual documented *procedure* rather than its prose, the
# `root` config creation below (when needed) briefly unmounts
# `/.snapshots`, lets `create-config` create and populate its own
# nested `.snapshots` subvolume normally, discards that, then restores
# the real top-level `@snapshots` subvolume in its place.
#
# Snapshots are root-only. archinstall's own setup_btrfs_snapshot() has
# been observed, by reading archinstall/lib/installer.py directly, to
# create both a `root` and a `home` Snapper config unconditionally (not
# conditional on the disk layout), with no way to opt out of the
# `home` one from the JSON config. Since this project deliberately
# doesn't snapshot /home (personal-file backup is the user's own
# concern, not this safety net's), and since /home has no dedicated
# `@home-snapshots` subvolume for it to reuse, that auto-created config
# would otherwise nest its own `.snapshots` inside `@home`, the exact
# problem `@snapshots` exists to avoid for root. So it's deleted here,
# before it can create even one snapshot.
#
# In practice, whether archinstall leaves either config behind at all
# has varied across runs/versions, so both the `home` deletion and the
# `root` creation below are made self-sufficient rather than assuming
# archinstall's own behavior: `home` is only deleted if present, and
# `root` is created here if archinstall didn't already create it.
#
# Boot-entry integration for snapshots is no longer archinstall's own
# _configure_grub_btrfsd() at all (decision #12): this project switched
# from GRUB to Limine, and the snapshot-boot mechanism is now a
# bespoke, sobarch-authored package (packages/custom/
# sobarch-limine-snapshots) rather than grub-btrfs/grub-btrfsd. That
# package is built and installed before this script runs
# (install_runner.py's _build_and_install_base_packages), so its
# service/binaries already exist on disk by the time the enablement
# below happens; inotify-tools stays in base.json's static package list
# since the new daemon still uses inotifywait, the same mechanism
# grub-btrfsd used.
#
# `@pkg`/`@log` don't exist either: the pacman cache and system logs
# live inside `@`, matching the Arch Wiki's own suggested layout
# exactly rather than adding two more subvolumes for a marginal,
# bounded benefit. The two effects of that are each addressed below
# rather than solved with a subvolume:
#   - Pacman cache churn: bounded by shrinking snap-pac's own
#     per-transaction retention (below) instead of leaving Snapper's
#     stock default of up to 50 kept.
#   - Losing /var/log on rollback: not actually a problem in practice.
#     scripts/snapshot-rollback.sh renames the previous @ rather than
#     deleting it, so pre-rollback logs (and cache) stay fully
#     inspectable under that renamed subvolume.
#
# `snapper rollback` is deliberately not part of this project's
# recovery path even with the `@snapshots` fix in place: the Wiki's own
# suggested layout is explicitly described as not intended to be used
# with it. Permanent rollback instead uses scripts/snapshot-rollback.sh,
# implementing the Wiki's documented manual procedure
# (https://wiki.archlinux.org/title/Snapper#Restoring_/_to_its_previous_snapshot).
# grub-btrfs (booting directly into a snapshot for inspection/recovery)
# is unaffected either way, and stays the primary, everyday recovery
# path.

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
    # Unmounting alone isn't enough: the empty directory that was used
    # as the mountpoint is still there afterward and blocks
    # create-config's subvolume creation the same way the mounted
    # subvolume did, so it has to be removed too.
    umount /.snapshots
    rmdir /.snapshots
    snapper --no-dbus -c root create-config /
    btrfs subvolume delete /.snapshots
    mkdir /.snapshots
    mount /.snapshots
    chmod 750 /.snapshots
fi

echo "snapper-setup.sh: applying retention preset (daily, 5 kept) to root..."

# Daily snapshots, 5 kept, no hourly/weekly/monthly/yearly. Also caps
# snap-pac's per-transaction "number" snapshots at 5/5 (Snapper's stock
# default is 50/10): since the pacman cache lives inside @ now, this
# bounds how many transactions' worth of cache stays pinned by old
# snapshots, matching the same small retention count used everywhere
# else in this preset.
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
