+++
title = "FAQ"
description = "Quick answers to the questions that come up before diving into the rest of the manual."
weight = 30
template = "docs/page.html"

[extra]
lead = "Short answers with links to the full page, for anything longer than a sentence."
toc = true
+++

## What desktop is this?

[Hyprland](https://hyprland.org/), themed as one piece; see
[Menu System](../../desktop/menu-system/) and
[Theming](../../desktop/theming/).

## Why isn't there an AUR helper?

An AUR helper can build arbitrary, unreviewed packages on demand,
which cuts against sobarch's minimalism and security goals. Everything
non-official is vendored, reviewed, and built the same way instead;
see [AUR & Custom Packages](../../packages/aur-and-custom/).

## How do I update everything?

**Super → Sobarch → Update System**, or `sobarch update` in a terminal.
It runs `pacman -Syu`, rebuilds any vendored package that's behind, and
merges config updates, asking before it touches anything you've
edited. A plain `pacman -Syu` also works; the vendored packages are
then updated in the background afterward. See
[Installing & Updating](../../packages/installing-updating/).

## How do I install something that isn't installed?

Optional software is in **Super → Sobarch → Install**, which lists every
[profile](../../installer/software-profiles/) package you don't have
yet. Anything else in the official repositories is a normal
`pacman -S`. There's no AUR helper, so other AUR packages are yours to
build by hand.

## Can I dual-boot with Windows or another OS?

Yes, if you free up disk space for it yourself first (the installer
never shrinks an existing partition for you). See
[Dual-Boot](../../installer/dual-boot/).

## Is my disk encrypted?

Optionally. The installer's Disk step has a toggle that LUKS-encrypts
the root partition, unlocked with a passphrase at boot; it's off by
default. See [Security](../security/) for what is and isn't covered.

## Why bash instead of zsh or fish?

Plain bash plus [ble.sh](../../shell-editor/terminal-and-shell/) gets
most of the fish/zsh conveniences (autosuggestions, syntax
highlighting, history search) without swapping the default shell.
Nothing stops you from switching to zsh or fish yourself; it's just
not what ships or gets reconciled by [Updating Your
Config](../../desktop/updating-system/).

## Is there a command-line tool?

Yes, a small one: `sobarch`, for update, config-conflict review,
package sync, snapshot restore, and rescue ISO refresh. See
[The sobarch Command](../../desktop/sobarch-command/).

## I'm stuck. Where do I get help?

Check [Troubleshooting](../troubleshooting/) first, then open an issue
on [GitHub](https://github.com/Dwarf1er/sobarch/issues).
