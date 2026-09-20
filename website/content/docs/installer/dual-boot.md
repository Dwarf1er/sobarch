+++
title = "Dual-Boot"
description = "Installing sobarch alongside an existing OS, into space you free up yourself."
weight = 55
template = "docs/page.html"

[extra]
lead = "The installer can install into existing free space instead of wiping the disk, but it never shrinks anything for you."
toc = true
+++

The installer supports installing into free space on a disk that
already has another OS on it (Windows, most commonly), rather than
wiping the whole disk. It does **not** shrink an existing partition for
you: you free up the space yourself first, the same way you would for
any other dual-boot install.

## 1. Free up space

From Windows: **Disk Management** → right-click the partition to shrink
→ **Shrink Volume** → enter how much space to free up. This becomes the
disk's unallocated space that sobarch installs into. Leave at least
20GiB free; less than that isn't enough for a comfortable install.

## 2. Install into the free space

On the disk-selection screen, a disk with enough free space on it (UEFI
only; see below) offers a second option alongside the usual "wipe
entire disk" one: installing into that free space instead. Picking it:

- Leaves every existing partition on the disk untouched.
- Reuses the disk's existing EFI System Partition (ESP) if it has one,
  rather than creating a second one -- the same ESP Windows' own
  bootloader already lives on ends up shared with sobarch's.
- Disables rescue media for this install (the extra partitions it
  needs aren't worth the added complexity on a disk already shared with
  another OS).

This is UEFI/GPT only. A BIOS/MBR disk never offers this option: MBR's
3-primary-partition limit is already tight for sobarch's own layout
(see [Rescue Media](../rescue-media/)), and dual-boot with an existing
OS is overwhelmingly a UEFI scenario anyway.

## 3. Add the other OS to the boot menu

Limine has no built-in equivalent to GRUB's `os-prober`, so after your
first boot into sobarch, open a terminal and run:

```
sudo /usr/local/lib/sobarch/limine-add-os-entry.sh
```

It lists the other bootloader(s) it finds on the shared ESP, asks which
one to add and what to call it, and writes the entry into Limine's boot
menu. Run it again for additional OSes, or to pick a different entry.

This approach (install into pre-existing free space, leave shrinking to
the user, add the other OS to the boot menu as a manual post-install
step) follows the same shape [Omarchy's own dual-boot
support](https://omarchy.org/manual/dual-boot-install/) takes.
