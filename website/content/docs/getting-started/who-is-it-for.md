+++
title = "Who It's For"
description = "Who Sobarch suits, who it doesn't, and what is still best-effort."
weight = 5
template = "docs/page.html"

[extra]
lead = "A small independent project: a considered Hyprland desktop on Arch for one person's machine, kept legible enough that yours can be the second."
toc = true
+++

## It suits you if

- You want Arch with a working, opinionated Hyprland desktop on the first
  boot, instead of assembling one over a weekend.
- You are comfortable with a keyboard-driven desktop built from small
  tools, with menus (fuzzel) rather than a settings application.
- You like knowing what is installed and why. Configuration is plain
  files under `~/.config`, merged rather than overwritten when the
  defaults change, and the reasoning is written down in the project's
  decision log.
- You want bootable Btrfs snapshots and a way back from a bad update,
  including from a system that no longer boots.
- You want packages from Arch's repositories plus a short, reviewed
  list of AUR packages, with no AUR helper and no third-party binary
  repository.

## It probably doesn't suit you if

- **You want a full desktop environment** such as GNOME or KDE, with a
  settings application for everything. Sobarch has menus for audio,
  network, Bluetooth, displays and a few more, and expects you to edit
  config files for the rest.
- **You need a fixed, long-lived release.** Sobarch follows Arch's
  rolling updates. The monthly ISO is an installer, not a stable
  platform.
- **You need to install offline.** Packages are downloaded, and vendored
  AUR packages are built, during the install.
- **You need mandatory access control or sandboxing.** There is no
  AppArmor and no sandboxing of installed software; see [Trust &
  Verification](../../reference/trust/).
- **You manage a fleet.** Unattended and PXE installs exist, but this
  is not an enterprise product and has no support commitment.

## What is still best-effort

- **NVIDIA.** Driver selection is based on the card's generation, but it
  has not been verified against real NVIDIA hardware.
- **Dual-boot and T2 Macs.** Both are supported and work, but they are
  covered by far fewer machines than a plain single-OS install.
- **Anything with a small user base.** Unusual hardware is more likely
  to hit a problem nobody has reported yet. `sobarch doctor` and an
  issue report are how those get fixed.

## Where to start

[Install it](../installation/) from the signed [prebuilt
ISO](../prebuilt-iso/), or from a stock Arch ISO. If something is
unclear or breaks, the [FAQ](../../reference/faq/) and
[Troubleshooting](../../reference/troubleshooting/) are the first stops.
