+++
title = "Installation"
description = "Boot the sobarch ISO, or a stock Arch ISO plus one command, and run the installer."
weight = 10
template = "docs/page.html"

[extra]
lead = "By default the installer partitions and wipes the entire target disk. It can also install into existing free space instead, for dual-boot alongside another OS."
toc = true
+++

There are two ways to reach the installer, and both end up in the same
TUI:

- **The sobarch ISO**, the primary route. It boots straight into the
  installer and has the base system's packages cached on it. See
  [Prebuilt ISO](../prebuilt-iso/) for downloading, verifying, and
  writing it to a USB drive.
- **A stock Arch ISO plus one command**, described below. It always
  fetches the newest installer from the repository.

## From the sobarch ISO

Write the [latest release](https://github.com/Dwarf1er/sobarch/releases/latest)
to a USB drive and boot it. The first console (tty1) launches the
installer on its own, so there is nothing to type. If the machine is
offline, the installer adds a **Network** step; see [Network
Step](../../installer/network-step/).

## From the official Arch ISO

If you would rather start from a stock image, boot the [official Arch
Linux ISO](https://archlinux.org/download/), connect to the network
(`iwctl` for Wi-Fi; wired works out of the box), then run:

```sh
curl -fsSL http://installsobarch.antoinepoulin.com | bash
```

`bootstrap.sh` fetches a checkout of the repository into a temp
directory and launches `installer/tui/__main__.py`, nothing else: no
separate hosting and nothing installed on top of the stock ISO. Any
arguments after `bash -s --` are passed through to the installer, which
is how an [unattended
install](../../installer/unattended-install/) is started.

Unlike the sobarch ISO, nothing is cached on this path, so the base
system's packages are downloaded and its vendored AUR packages are
built during the install.

If you would rather not type Wi-Fi commands, start the installer anyway:
when the machine has no connectivity, a **Network** step is added to the
installer itself. See [Network Step](../../installer/network-step/).

## The installer

Both UEFI and BIOS machines are supported; the title bar shows which
mode the installer detected. The TUI is a single screen: a list of steps
on the left (Disk, Account, Locale, Options, Software, Install, plus
Network first when the machine is offline) and the selected step's form
on the right. Fill in each step in any order, then use the Install step to
review a summary and start the install. Starting it asks you to type the
target disk's name to confirm, since it is destructive. See [Disk &
Account Setup](../../installer/disk-and-accounts/) for every step.

The install itself hands off to `archinstall` and then runs sobarch's own
post-install steps; see [What the Install Does](../../installer/install-process/).
On success you get **Reboot now** and **Quit** choices; the machine does not
reboot on its own. On failure the installer points at the full install
log rather than hiding it behind a branded screen. The log appears in the
same pane as the steps. Look for `install.log` in `/root/sobarch-install/`
(the same directory the generated `archinstall` config is saved to).

After the reboot, see [First Boot](../first-boot/) for what finishes
setting up in the background.
