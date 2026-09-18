+++
title = "Rescue Media"
description = "A full Arch ISO kept on local disk for when a machine can't boot."
weight = 50
template = "docs/page.html"

[extra]
lead = "Two extra partitions hold a full Arch ISO on local disk, so recovery doesn't depend on having a USB drive on hand."
toc = true
+++

The disk layout reserves two dedicated partitions by default: about
5.5GB total (512MB FAT32 + 5GB ext4), on top of whatever your root
filesystem needs. Opt out of both together if you're tight on disk
space:

- A small FAT32 partition holding the extracted kernel and initramfs.
- A larger ext4 partition holding the fetched Arch ISO itself, as a
  plain file.

The split exists because the bootloader (Limine) can't read ext4 and
has no GRUB-style loopback command, and FAT32 has a hard 4GB per-file
cap that the ISO itself would run into. During install, this is fetched
from an official mirror, checksum-verified, and wired into a permanent
boot menu entry, the same mechanism the official Arch installation
media itself uses to loop-mount an ISO file at boot.

The stored ISO is refreshed manually only, never automatically. A
background download on every boot or update would be surprising and
wasteful, and a slightly outdated rescue ISO is still far better than
none at all.

This is what [snapshot rollback](../snapshots/#restoring-a-snapshot-as-the-new-root)'s
live-ISO mode uses when there's no other way to boot the machine.
