+++
title = "Snapshots"
description = "Automatic BTRFS snapshots, boot-time recovery, and manual rollback."
weight = 40
template = "docs/page.html"

[extra]
lead = "Every install gets automatic root snapshots, recoverable straight from the boot menu without touching or replacing anything."
toc = true
+++

Every install gets automatic BTRFS snapshots via Snapper + `snap-pac`,
set up almost entirely by `archinstall` itself: package installs,
Snapper's config, and the systemd timers all happen as part of the
same install run. Snapshots are root-only; personal file backup is a
separate concern, left to your own tools.

Retention is tuned tighter than Snapper's defaults: daily snapshots, 5
kept, with `snap-pac`'s per-transaction limit lowered to 5 as well.
Bounded disk usage doesn't rely on those counts alone: Snapper's own
space/free-space limits mean the cleanup timer prunes older snapshots
if free space drops below 20%, regardless of count.

## Recovering from the boot menu

Day-to-day recovery goes through the boot menu: reboot, pick an older
snapshot from the Limine menu, inspect or recover a file, reboot back.
Nothing is touched or replaced by browsing a snapshot this way.

This boot-menu integration is a small sobarch-authored package
(`sobarch-limine-snapshots`), not a vendored one. The obvious
off-the-shelf option, `limine-snapper-sync`, builds as a Java native
binary requiring a large JDK download and a full Gradle build on every
single install, a much heavier and less predictable install-time cost
than anything else this project vendors, on a live-ISO environment of
unknown RAM. Writing a small, purpose-built equivalent was more
reliable than depending on it.

## Restoring a snapshot as the new root

For the rarer case of wanting an old snapshot to become the new
permanent root (rather than just recovering a file), `scripts/
snapshot-rollback.sh` implements the [documented manual BTRFS/Snapper
procedure](https://wiki.archlinux.org/title/Snapper#Restoring_/_to_its_previous_snapshot)
directly, not the `snapper rollback` subcommand (which sobarch's disk
layout isn't meant to be used with). It supports two modes:

- From a **live ISO or rescue chroot**: the only mode that always
  works, even if the installed system can't boot at all.
- **`--online`**, run directly on the currently booted system, no live
  media needed.
