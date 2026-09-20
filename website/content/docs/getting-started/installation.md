+++
title = "Installation"
description = "Boot the official Arch ISO and run the bootstrap script."
weight = 10
template = "docs/page.html"

[extra]
lead = "The installer only supports full-disk installs: it partitions and wipes the entire target disk. Dual/multi-boot is not supported."
toc = true
+++

Boot the [official Arch Linux ISO](https://archlinux.org/download/), connect to
the network (`iwctl` for Wi-Fi; wired works out of the box), then run:

```sh
curl -fsSL http://installsobarch.antoinepoulin.com | bash
```

This is the only manually-typed, unbranded step. `bootstrap.sh` fetches a
checkout of the repository into a temp directory and launches
`installer/tui/__main__.py`, nothing else: no separate hosting, no custom ISO.
The TUI then walks through disk selection, account/locale setup, and optional
software profiles before handing off to `archinstall`. On success it reboots
into a working desktop; on failure it points at the full install log rather
than hiding it behind a branded screen. Look for `install.log` in
`/root/sobarch-install/` (the same directory the generated `archinstall`
config is saved to).
