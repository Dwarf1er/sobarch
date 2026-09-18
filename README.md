<div align="center">

# Sobarch
##### A minimal, reproducible Arch Linux + Hyprland desktop setup

<img alt="Sobarch logo" height="280" src="branding/sobarch-logo.svg" />

![License](https://img.shields.io/github/license/Dwarf1er/sobarch?style=for-the-badge)
![Issues](https://img.shields.io/github/issues/Dwarf1er/sobarch?style=for-the-badge)
![PRs](https://img.shields.io/github/issues-pr/Dwarf1er/sobarch?style=for-the-badge)
![Stars](https://img.shields.io/github/stars/Dwarf1er/sobarch?style=for-the-badge)

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

## Quickstart

Boot the [official Arch Linux ISO](https://archlinux.org/download/),
connect to the network (`iwctl` for Wi-Fi; wired works out of the box),
then run:

    curl -fsSL https://raw.githubusercontent.com/Dwarf1er/sobarch/master/bootstrap.sh | bash

This is the only manually-typed, unbranded step. It fetches this
repository and launches the TUI installer, which walks through disk
selection, account/locale setup, and optional software profiles before
handing off to `archinstall`.

**Note:** the installer only supports full-disk installs. It partitions
and wipes the entire target disk; dual/multi-boot is not supported.

## License

This software is licensed under the [MIT license](LICENSE).
