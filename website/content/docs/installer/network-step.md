+++
title = "Network Step"
description = "Connecting to Wi-Fi from inside the installer when there is no wired link."
weight = 5
template = "docs/page.html"

[extra]
lead = "The installer needs the network. If the machine is offline when it starts, a Network step is added so you can connect without leaving the TUI."
toc = true
+++

At startup the installer checks real reachability (it fetches
`archlinux.org`), not just whether a link exists. If that check fails, a
**Network** step appears first in the Steps list. It is decided once per
session, so the list never shifts under you. On a wired machine with
working internet you never see it.

The step is Wi-Fi only and drives `iwd`, the same tool as `iwctl` on the
live ISO:

- **Scan for networks** lists nearby networks with their security type and
  signal. Pick one with Enter to fill in the name.
- **SSID** and **Passphrase** can also be typed by hand. Typing is the
  reliable path; scanning is a convenience on top, and an empty scan
  result just means you enter the name yourself.
- **Connect** joins the network and reports the result below.

Only the first Wi-Fi adapter is used. If none is found the step says so,
and you can still connect yourself with `iwctl` before starting the
installer.

The connection exists only on the live ISO. It is not copied into the
installed system, so a Wi-Fi-only machine connects again after its first
login; the [first-boot](../../getting-started/first-boot/) package and
security steps wait for that connection.
