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

## Can I dual-boot with Windows or another OS?

No. The installer only supports full-disk installs: the entire target
disk is partitioned and wiped. See
[Disk & Account Setup](../../installer/disk-and-accounts/).

## Is my disk encrypted?

No, the installer doesn't offer disk encryption. See
[Security](../security/) for what is and isn't covered.

## Why bash instead of zsh or fish?

Plain bash plus [ble.sh](../../shell-editor/terminal-and-shell/) gets
most of the fish/zsh conveniences (autosuggestions, syntax
highlighting, history search) without swapping the default shell.
Nothing stops you from switching to zsh or fish yourself; it's just
not what ships or gets reconciled by [Updating Your
Config](../../desktop/updating-config/).

## I'm stuck. Where do I get help?

Check [Troubleshooting](../troubleshooting/) first, then open an issue
on [GitHub](https://github.com/Dwarf1er/sobarch/issues).
