+++
title = "Prebuilt ISO"
description = "The monthly sobarch ISO: boots straight into the installer, with the base packages cached."
weight = 15
template = "docs/page.html"

[extra]
lead = "A second way to install: an ISO that boots directly into the installer and resolves the base system from local disk instead of the network."
toc = true
+++

A prebuilt installer ISO is published every month as a GitHub release at
[github.com/Dwarf1er/sobarch/releases/latest](https://github.com/Dwarf1er/sobarch/releases/latest).
It is built a few days after Arch's own monthly ISO, on the fifth, from
Arch's own `releng` profile, so the kernel and live tools track upstream.
Each release carries the ISO (`sobarch-YYYY.MM.DD-x86_64.iso`) and a
detached signature next to it (`.iso.sig`).

It does not replace the [official ISO path](../installation/), which
stays available and always runs the newest installer. The installer on the
ISO is whatever was current when that month's image was built.

## What is different

- **It boots straight into the installer.** The first console
  (tty1) auto-launches the TUI, so there is no command to type.
- **The base system's packages are cached on it.** The official packages
  and the vendored AUR packages the base install needs are in a local
  repository on the image, so the install resolves them from disk
  instead of downloading them. Packages the installer would otherwise
  build from source are prebuilt too; the installer reuses a cached
  build only when its version matches the pinned one, and builds
  normally otherwise.
- **Optional software profiles are not cached.** They install over the
  network at first boot exactly as they do from the official ISO, so a
  network connection is still needed.
- **It works for unattended and PXE installs.** If a `script=` kernel
  parameter is present, the ISO runs that script instead of launching the
  TUI, the same hook the official ISO provides. See [PXE
  Netboot](../../installer/pxe-netboot/).

The installer, partitioning, and result are identical to the other path.

## Verifying the download

Each release is signed with a project-dedicated key (fingerprint
`9CC2 2D5E C575 F128 628E  A8F6 AFC1 54B3 F842 8676`). The public key is
[`sobarch-iso-signing.asc`](https://github.com/Dwarf1er/sobarch/blob/master/sobarch-iso-signing.asc)
in the repository. Import it once, then verify the same way you would the
official Arch ISO's `.sig`:

```sh
gpg --import sobarch-iso-signing.asc
gpg --verify sobarch-YYYY.MM.DD-x86_64.iso.sig sobarch-YYYY.MM.DD-x86_64.iso
```

GitHub also shows a SHA256 digest next to each release asset, if you only
want a plain checksum comparison.

## Writing it to a USB drive

Write the ISO to a drive the same way as any Arch ISO, for example with
`dd`:

```sh
sudo dd if=sobarch-YYYY.MM.DD-x86_64.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Replace `/dev/sdX` with the whole USB device, not a partition. The
installer never offers the disk it booted from as an install target.
