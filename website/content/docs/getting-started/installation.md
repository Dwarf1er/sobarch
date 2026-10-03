+++
title = "Installation"
description = "Boot the official Arch ISO and run the bootstrap script."
weight = 10
template = "docs/page.html"

[extra]
lead = "By default the installer partitions and wipes the entire target disk. It can also install into existing free space instead, for dual-boot alongside another OS."
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
The TUI is a single screen: a list of steps on the left (Disk, Account,
Locale, Options, Software, Install, plus Network first when the machine
is offline) and the selected step's form on the right. Fill in each step
in any order, then use the Install step to review a summary and start the
install, which hands off to `archinstall`. On success it reboots
into a working desktop; on failure it points at the full install log rather
than hiding it behind a branded screen. The install log appears in the
same pane as the steps, followed by Reboot and Quit choices. Look for `install.log` in
`/root/sobarch-install/` (the same directory the generated `archinstall`
config is saved to).
