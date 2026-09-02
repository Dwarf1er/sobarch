#!/bin/bash
# Snapper retention preset, run by the TUI as the same
# post-archinstall, pre-reboot arch-chroot step as nvidia-setup.sh.
#
# `@snapshots` (base.json's disk_config) is what makes this safe to run
# at all: it's already mounted at /.snapshots as its own top-level
# BTRFS subvolume before this runs, so `snapper create-config` detects
# and reuses it instead of nesting `.snapshots` inside `@`. This is the
# Arch Wiki's own documented fix for a well-known problem with the flat
# Arch-recommended layout: if `.snapshots` lives inside `@`, replacing
# `@` during a rollback wipes the snapshot history out along with it.
# (https://wiki.archlinux.org/title/Snapper#Suggested_filesystem_layout)
#
# Snapshots are root-only. archinstall's own setup_btrfs_snapshot()
# unconditionally creates a second Snapper config for `home`/`/home`
# (confirmed by reading archinstall/lib/installer.py directly: the two
# configs are hardcoded, not conditional on the disk layout), with no
# way to opt out of its creation from the JSON config. Since this
# project deliberately doesn't snapshot /home (personal-file backup is
# the user's own concern, not this safety net's), and since /home has
# no dedicated `@home-snapshots` subvolume for it to reuse, that
# auto-created config would otherwise nest its own `.snapshots` inside
# `@home`, the exact problem `@snapshots` exists to avoid for root. So
# it's deleted here, before it can create even one snapshot.
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

echo "snapper-setup.sh: deleting the auto-created 'home' Snapper config (snapshots are root-only)..."

snapper --no-dbus -c home delete-config

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

echo "snapper-setup.sh: done."
