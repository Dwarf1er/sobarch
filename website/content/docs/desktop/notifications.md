+++
title = "Notifications"
description = "How notifications look, what sobarch tells you about, and how to silence them."
weight = 80
template = "docs/page.html"

[extra]
lead = "mako shows notifications, and a few background jobs use them to tell you about updates, failures, and a snapshot boot."
toc = true
+++

Notifications come from [mako](https://github.com/emersion/mako),
colored by the active [theme](../theming/). They appear at the top right
over everything else, and the newest is shown first. A normal one
disappears after five seconds. A critical one stays until you click or
dismiss it.

## Do not disturb

`Super+D` toggles do-not-disturb, and so does clicking the bell
indicator in waybar. While it's on, notifications are hidden rather than
discarded, and the indicator in the bar shows that it's active.

## What sobarch notifies you about

### Updates available

A daily check (a systemd user timer that first runs about ten minutes
after login) looks for two things without installing anything:

- Pending official package updates, or a newer `sobarch-skel` or
  `sobarch-scripts`. The notification says so and, when clicked, opens
  **Update System** ([details](../updating-system/)).
- If you set up [rescue media](../../installer/rescue-media/), a newer Arch
  ISO than the one on the rescue partition. Clicking opens **Refresh
  Rescue ISO**.

Each notification is shown once per distinct situation, so an unchanged
backlog doesn't nag you every day. The system update one is re-armed
weekly in case you missed it. If you're offline the check stays silent
rather than claiming everything is current.

### Package update failures

When the pacman hook syncs the vendored AUR/custom packages after a
`pacman -Syu` and one of them fails to build or install, a critical
"Package update failed" notification lists what failed. Details are in
`/var/log/sobarch/aur-sync.log`. The first-boot steps that run in the
background (the security baseline and the optional package install)
report their progress and any failure the same way, since they'd
otherwise fail where you can't see them.

### Booted into a snapshot

If you picked a snapshot entry in the Limine boot menu, a persistent
notification appears at login saying you're running snapshot `N`, and
that changes made in this session are lost on the next normal boot.
Clicking it offers to make that snapshot your permanent system, after a
confirmation, using the same restore as `sobarch snapshot-restore`. A
progress notification follows, then an offer to reboot. See
[Snapshots](../../installer/snapshots/) for the whole picture.

### Progress and results

Menus that take a while show a progress notification that is replaced by
the result when it finishes: scanning for Wi-Fi or Bluetooth devices,
firmware updates, installing a package, refreshing the rescue ISO, and
the system update itself. Failures use the critical style and include
the error text.
