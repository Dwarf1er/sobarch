<div align="center">

# Sobarch
##### A minimal, reproducible Arch Linux + Hyprland desktop setup

<img alt="Sobarch logo" height="280" src="branding/sobarch-logo.svg" />

![License](https://img.shields.io/github/license/Dwarf1er/sobarch?style=for-the-badge)

</div>

A minimal, reproducible Arch Linux + Hyprland desktop setup: installer,
versioned configuration, and package tooling in one repo.

Sobarch started after a dotfiles repository grew into a pile of
OS-level tweaks, packages, and installation scripts. Rebuilding that as
a small, reproducible environment turned out to be less overhead than
letting the dotfiles spaghetti keep growing. The goals: minimalistic in
all aspects, as close to upstream Arch as possible, no custom package
repository, and as little custom tooling as possible.

It's primarily built for its maintainer, but aims to stay understandable
and usable by others.

## What's included

**Desktop.** Hyprland, Waybar, Mako notifications, Fuzzel launcher, Kitty,
and `ly` as the display manager, with `hyprlock`/`hypridle`/`hyprpaper`/
`hyprshot`/`hyprpicker` rounding out locking, idle handling, wallpapers,
and screenshots. GPU driver selection (including NVIDIA generation
detection) is automatic during install.

**One theme, the whole desktop.** Every app config is generated from the
same base16/base24 color scheme via `tinty`, so picking a new theme from
the built-in menu recolors the terminal, bar, launcher, and editor
together instead of one app at a time.

**Snapshots you can actually boot into.** BTRFS root snapshots (Snapper)
show up as their own boot entries directly in the Limine bootloader menu,
and a dedicated on-disk partition carries a spare Arch ISO so a rollback
is possible even if the installed system won't boot at all, no separate
USB drive needed.

**Security baseline, applied by default.** A default-deny `nftables`
firewall and a locked root account ship out of the box; SSH stays off
unless enabled during install.

**No terminal required for day-to-day upkeep.** A Fuzzel-driven menu
(bound to the Super key) covers pulling config updates and walking
through any merge conflicts, installing additional packages, switching
themes/wallpapers, and refreshing the rescue ISO.

**Optional software profiles**, applied after first boot and left
unchecked by default:

| Profile | Included |
| --- | --- |
| Developer | `mise`, `presenterm` |
| Gaming | Steam, Lutris, Prism Launcher, gamescope, MangoHud, Protontricks, ProtonUp-Qt |
| Creative | GIMP, Inkscape, OBS Studio, Shotcut, Audacity, EasyEffects, Calf, LSP plugins |
| Maker / 3D Printing | Blender, FreeCAD, OrcaSlicer |
| Virtualization | QuickEMU, QuickGUI |
| Office | LibreOffice, Homebank |
| Browsers & Chat | Brave, Signal, Vesktop |
| System Tuning | TLP, LACT, nvtop, smartmontools, ethtool, VIA keyboard support |
| Input Method | fcitx5 (CJK, Hangul) |

Each profile can also be expanded to hand-pick individual packages
instead of taking it as a whole, and "install everything" is a single
toggle away.

**Packages come from two places only**: Arch's official repositories,
and a small set of AUR packages vendored and reviewed into this repo,
built locally by a dedicated build user. No AUR helper, no third-party
binary repository.

## Quickstart

Boot the [official Arch Linux ISO](https://archlinux.org/download/),
connect to the network (`iwctl` for Wi-Fi; wired works out of the box),
then run:

    curl -fsSL http://installsobarch.antoinepoulin.com | bash

This is the only manually-typed, unbranded step. It fetches this
repository and launches the TUI installer, which walks through disk
selection, account/locale setup, and optional software profiles before
handing off to `archinstall`.

**Note:** the installer only supports full-disk installs. It partitions
and wipes the entire target disk; dual/multi-boot is not supported.

## License

This software is licensed under the [MIT license](LICENSE).
