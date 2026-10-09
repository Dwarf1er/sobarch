+++
title = "AUR & Custom Packages"
description = "No AUR helper is installed. Here's what runs instead."
weight = 10
template = "docs/page.html"

[extra]
lead = "AUR packages are vendored as reviewed PKGBUILD snapshots and built locally, rather than pulled through a general-purpose AUR helper."
toc = true
+++

Two kinds of non-official packages exist in this repo:

- **`packages/aur/`**: PKGBUILD snapshots of genuinely upstream AUR
  packages sobarch depends on.
- **`packages/custom/`**: sobarch's own packages, often packaging
  content that lives elsewhere in this same repo.

Both are built and installed the same way. There's no AUR helper
installed or required anywhere on the system. An AUR helper can build
arbitrary, unreviewed AUR packages on demand, which cuts against
sobarch's minimalism and security goals: every PKGBUILD that does end
up vendored here is reviewed and scanned before merge, not fetched and
built blind at install time. The build script also refuses any name
that isn't actually present in those two directories, so it can't be
pointed at an arbitrary package.

Because Arch's official repositories evolve, packages vendored from
the AUR are periodically re-checked and migrated out once they
graduate to `extra`: vendoring is a means, not a commitment to stay
on the AUR forever.

## Vendored AUR packages

| Package | What it is | Pulled in by |
| --- | --- | --- |
| `localsend-bin` | Open-source, AirDrop-style file sharing | Every install |
| `blesh-git` | ble.sh, the Bash line editor used by the [shell setup](../../shell-editor/terminal-and-shell/) | Every install |
| `tinty-git` | Base16/Base24 colour scheme manager behind [theming](../../desktop/theming/) | Every install |
| `gale-bin` | Lightweight Thunderstore mod client | [Gaming profile](../../installer/software-profiles/) |
| `protonup-qt-bin` | Installs Proton-GE for Steam and Wine-GE for Lutris | Gaming profile |
| `orca-slicer-bin` | G-code slicer for 3D printers | Maker / 3D Printing profile |
| `quickemu-git` | Quickly create and run Windows, macOS and Linux VMs | Virtualization profile |
| `quickgui-bin` | Flutter frontend for `quickemu` | Virtualization profile |
| `brave-origin-bin` | Brave's minimalist browser build | Browsers & Chat profile |
| `vesktop-bin` | Vesktop, a Discord client with Vencord built in | Browsers & Chat profile |
| `nvidia-580xx-utils`, `lib32-nvidia-580xx-utils` | Legacy NVIDIA 580xx driver branch (one build also produces the matching DKMS and OpenCL packages) | Installer, only when a Maxwell, Pascal or Volta GPU is detected |

The "every install" packages are built synchronously during the
install itself, before first boot. Profile packages are installed
after first boot, as described in
[Software Profiles](../../installer/software-profiles/).

## Custom packages

| Package | What it ships |
| --- | --- |
| `sobarch-skel` | The default desktop configuration (the dotfiles merged into `$HOME` by [Updating Your Config](../../desktop/updating-system/)), the profile list the Install menu reads, and the branding assets used for the boot splash, boot menu and login screen. |
| `sobarch-scripts` | The `sobarch` command, the update flow, the package sync script and its pacman hook, the first-boot scripts, the NetworkManager dispatcher script, the daily update-check timer, and the snapshot restore and rescue refresh helpers. Scripts live in `/usr/local/lib/sobarch/`. |
| `sobarch-limine-snapshots` | The service that keeps one Limine boot entry per Snapper snapshot, so any snapshot can be booted straight from the boot menu. See [Snapshots](../../installer/snapshots/). |
| `sobarch-via-udev` | A udev rule granting `hidraw` access so keyboards can be configured from the VIA web app (usevia.app) without root. Opt-in through the System Tuning profile; an already-plugged-in keyboard is picked up on install, no reboot needed. |
| `vesktop-integrity-launch` | A launch wrapper for Vesktop that checks the Vencord files against a local baseline and runs Vesktop's own repair when they don't match. |

### How the Vesktop wrapper is installed

`vesktop-integrity-launch` is not a profile choice of its own. It's a
companion of `vesktop-bin`: whenever `vesktop-bin` is installed by
name (from the Install menu, first boot, or `sobarch aur-sync
vesktop-bin`), the wrapper is built and installed alongside it. A pacman hook
then writes a menu entry in `/usr/local/share/applications/` that
overrides the stock one so launching Vesktop from the app launcher goes
through the wrapper. The override is regenerated on every
`vesktop-bin` change and removed again if either package goes away; the
file `vesktop-bin` owns is never touched. Once installed, the wrapper
is kept current by the normal sync like any other vendored package.

## How vendored packages are vetted

A weekly CI job compares each vendored AUR package with its upstream
AUR repository. For a normal package it compares versions. For a
`-git` package, whose version is recomputed at build time and so says
nothing about whether upstream moved, it compares the PKGBUILD content
instead. When something differs, the job opens a pull request with the
new snapshot, along with the output of two advisory checks: `namcap`
(a PKGBUILD linter) and a static security scan of the package files.
It also fails the run if a package's committed `.SRCINFO` doesn't
match its PKGBUILD, because that file is what the sync script trusts
for the version to install. Nothing merges without a human reading the
diff.

Sobarch's own custom packages are checked locally instead: a git
pre-commit hook rebuilds each `.SRCINFO` and, if a package's payload
changed without a version bump, bumps it and stages the fix.
Contributors enable it once per clone with
`scripts/install-git-hooks.sh`.
