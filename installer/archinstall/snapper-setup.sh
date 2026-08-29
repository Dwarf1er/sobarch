#!/bin/bash
# Snapper retention preset, run by the TUI as the same
# post-archinstall, pre-reboot arch-chroot step as nvidia-setup.sh (see
# that script's header for why this runs here rather than via
# archinstall's own custom_commands).
#
# `@snapshots`/`@home-snapshots` (base.json's disk_config) are what
# make this safe to run at all: both are already mounted at
# /.snapshots and /home/.snapshots respectively as their own top-level
# BTRFS subvolumes before this runs, so `snapper create-config` detects
# and reuses them instead of nesting `.snapshots` inside `@`/`@home`.
# This is the Arch Wiki's own documented fix for a well-known problem
# with the flat Arch-recommended layout: if `.snapshots` lives inside
# `@`, replacing `@` during a rollback wipes the snapshot history out
# along with it.
# (https://wiki.archlinux.org/title/Snapper#Suggested_filesystem_layout)
#
# `snapper rollback` is deliberately not part of this project's
# recovery path even with that fix in place: the Wiki's own suggested
# layout is explicitly described as not intended to be used with it.
# Permanent rollback instead uses scripts/snapshot-rollback.sh,
# implementing the Wiki's documented manual procedure
# (https://wiki.archlinux.org/title/Snapper#Restoring_/_to_its_previous_snapshot).
# grub-btrfs (booting directly into a snapshot for inspection/recovery)
# is unaffected either way, and stays the primary, everyday recovery
# path.

set -euo pipefail

for mnt in /.snapshots /home/.snapshots; do
    if ! mountpoint -q "$mnt"; then
        echo "error: $mnt is not a separate mounted subvolume; refusing to continue (would nest .snapshots inside its parent)" >&2
        exit 1
    fi
done

echo "snapper-setup.sh: applying retention preset (daily, 5 kept) to root and home..."

# Daily snapshots, 5 kept, no hourly/weekly/monthly/yearly. Same preset
# for both configs, for predictable, bounded disk usage from either.
for config in root home; do
    sed -i \
        -e 's/^TIMELINE_LIMIT_HOURLY=.*/TIMELINE_LIMIT_HOURLY="0"/' \
        -e 's/^TIMELINE_LIMIT_DAILY=.*/TIMELINE_LIMIT_DAILY="5"/' \
        -e 's/^TIMELINE_LIMIT_WEEKLY=.*/TIMELINE_LIMIT_WEEKLY="0"/' \
        -e 's/^TIMELINE_LIMIT_MONTHLY=.*/TIMELINE_LIMIT_MONTHLY="0"/' \
        -e 's/^TIMELINE_LIMIT_YEARLY=.*/TIMELINE_LIMIT_YEARLY="0"/' \
        "/etc/snapper/configs/$config"
done

echo "snapper-setup.sh: creating initial snapshot..."

snapper --no-dbus -c root create --description "Initial system setup"

echo "snapper-setup.sh: done."
