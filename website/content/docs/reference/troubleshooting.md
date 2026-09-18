+++
title = "Troubleshooting"
description = "Where to look when the installer, first boot, or a config update doesn't go as expected."
weight = 20
template = "docs/page.html"

[extra]
lead = "Most failure points here fail loud on purpose: a log file, a marker file, or a systemd unit you can inspect directly, rather than a silent skip."
toc = true
+++

## The installer fails

Check `install.log` in `/root/sobarch-install/` (the same directory
the generated `archinstall` config is saved to); see
[Installation](../../getting-started/installation/). The install
command is safe to re-run: it just re-fetches the repo and relaunches
the TUI from the start.

## A first-boot step doesn't seem to have run

The package-install and security-baseline units only start once a
network connection comes up, not at ordinary boot; see
[First Boot](../../getting-started/first-boot/) for why. If you've
connected and it still hasn't run, check the unit directly:

```sh
systemctl status sobarch-firstboot-packages.service
journalctl -u sobarch-firstboot-security.service
```

Both are safe to start by hand if you don't want to wait for the
dispatcher: `systemctl start --no-block sobarch-firstboot-packages.service`.

## Boot splash, boot menu, or login screen branding is missing

[Boot & Login Theming](../../desktop/boot-theming/) covers what should
be showing at each stage. Running
[Update Config](../../desktop/updating-config/) re-applies all three
unconditionally, which is the quickest way to rule out a one-off
glitch before digging further.

## Hyprland doesn't seem to pick up a config change

Run `hyprctl reload` directly. Hyprland's own config watcher can miss
an atomic file replace (the kind [Updating Your
Config](../../desktop/updating-config/)'s merge does), so a change
landing on disk doesn't always mean it's been picked up yet.

## A vendored package fails to build

The [package sync mechanism](../../packages/installing-updating/) runs
on every `pacman -Syu`; its output appears inline in that same
transaction, so scroll back through it first. To retry a single
package directly instead of waiting for the next upgrade:

```sh
sudo /usr/local/lib/sobarch/aur-sync.sh <package-name>
```

## Something broke and you want to go back

[Snapshots](../../installer/snapshots/) cover both recovering a file
from the boot menu and restoring an older snapshot as the new root,
including from a live ISO if the system won't boot at all.
