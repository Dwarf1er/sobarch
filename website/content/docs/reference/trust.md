+++
title = "Trust & Verification"
description = "What you are trusting when you install Sobarch, how releases are signed, how vendored packages are vetted, and what is out of scope."
weight = 15
template = "docs/page.html"

[extra]
lead = "Sobarch is a small independent project. This page says plainly what you are relying on and what protects you."
toc = true
+++

## What you are trusting

- **Arch Linux itself.** Official packages come from Arch's mirrors and
  are checked with pacman's signature verification, as on any Arch install.
- **The Sobarch repository on GitHub.** The installer, the first-boot and
  update scripts, and the `sobarch-*` packages are built from it. Installing
  means running code from `master` (or from a monthly ISO built from it) as
  root on your machine.
- **The maintainer's review of vendored AUR packages**, described below.

There is no hosted package repository: packages are built on your machine
from the repository's own files.

## The install command

`curl -fsSL http://installsobarch.antoinepoulin.com | bash` runs
`bootstrap.sh`. That short address is plain HTTP and redirects to the file
on `raw.githubusercontent.com`, so the first request is not protected
against someone on your network. To skip that hop, run the GitHub address
directly, which is HTTPS from the start:

```sh
curl -fsSL https://raw.githubusercontent.com/Dwarf1er/sobarch/master/bootstrap.sh | bash
```

`bootstrap.sh` then downloads the current `master` branch as a tarball from
GitHub over HTTPS and starts the installer. It is not pinned to a release,
so it always runs the newest installer. If you would rather not run a piped
script, read [`bootstrap.sh`](https://github.com/Dwarf1er/sobarch/blob/master/bootstrap.sh)
first (it is short), or use the signed prebuilt ISO instead.

## Verifying the ISO

Each monthly release is signed with a project-dedicated GPG key, fingerprint
`9CC2 2D5E C575 F128 628E  A8F6 AFC1 54B3 F842 8676`. The steps are on
[Prebuilt ISO](../../getting-started/prebuilt-iso/#verifying-the-download).
The public key is published in the repository, and the fingerprint is
printed here and on that page, so you can compare it across two places
rather than trusting one. Both are served by the same project, so a
signature proves the ISO matches what the project's key signed, not that
the project itself is trustworthy.

## How vendored AUR packages are vetted

Packages from the AUR are copied into the repository as reviewed snapshots
and built locally; there is no AUR helper and nothing is fetched from the
AUR at install time.

- A weekly CI job compares each snapshot with its upstream and opens a pull
  request for any difference, with `namcap` and a static security scan of the
  package files attached.
- A human reads every diff before it merges.
- The build script refuses any package name that isn't present in the
  repository's `packages/aur/` or `packages/custom/`.
- Packages are built as a dedicated unprivileged `sobarch-build` user. Only
  the final `pacman -U` runs as root.

Details are on [AUR & Custom Packages](../../packages/aur-and-custom/#how-vendored-packages-are-vetted).

## What it protects against

- A tampered ISO download (signature check).
- Network attackers on the installer download (HTTPS) and on packages
  (pacman signatures).
- A malicious or compromised AUR package update slipping in unnoticed
  (review plus scanning plus the unprivileged build).
- Inbound network access to a fresh install and root login (the
  [security baseline](../security/)).

## What it does not protect against

- A compromise of the maintainer's GitHub account or the signing key.
- A compromise of upstream software that a package builds, which a diff
  of the PKGBUILD alone may not reveal (sources and checksums are what
  the scan and the reviewer look at).
- A malicious application running as you: there is no mandatory access
  control, and no sandboxing of installed packages.
- Physical access to an unencrypted disk, or to a machine you left
  unlocked. Disk encryption is optional.

Report anything you find through [SECURITY.md](https://github.com/Dwarf1er/sobarch/blob/master/SECURITY.md).
