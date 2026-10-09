+++
title = "Files & Logs"
description = "Where sobarch keeps its logs, flags, and state, so you know what to inspect or reset."
weight = 50
template = "docs/page.html"

[extra]
lead = "Everything sobarch records is a plain file you can read. Most of it is a marker that says a one-time step already ran."
toc = true
+++

## Logs

| Path | Contents |
| --- | --- |
| `/root/sobarch-install/install.log` | The installer's own log, on the live ISO. |
| `/var/log/sobarch/aur-sync.log` | Every vendored-package sync, whether run by the pacman hook, **Update System**, or by hand. |
| `journalctl -u sobarch-aur-sync` | The same sync when the pacman hook started it. |
| `journalctl -u sobarch-firstboot-packages.service` (and `-security`, `-skel`, `-git`, `-rfkill`) | The first-boot units. |
| `journalctl --user -u sobarch-update-check` | The daily update check. |

## First-boot markers

Each first-boot step writes a marker only after it succeeds, so a
failed step retries on the next network connection instead of being
skipped. Deleting a marker makes that step run again.

| Marker | Step |
| --- | --- |
| `/var/lib/sobarch/profile-packages-installed` | Optional profile packages |
| `/var/lib/sobarch/security-baseline-applied` | [Security baseline](../security/) |
| `/var/lib/sobarch/rfkill-unblocked` | Wi-Fi/Bluetooth rfkill unblock |
| `~/.local/state/sobarch/git-setup-done` | SSH key generation and git identity for your account |

## Flags and records

| Path | Contents |
| --- | --- |
| `/etc/sobarch/ssh-enabled` | `true` or `false`, written by the installer's SSH option. |
| `/etc/sobarch/git-identity` | The git identity entered during install, applied to your account at first boot. |
| `/var/lib/sobarch/rescue-iso-sha256` | Checksum of the ISO on the rescue partition, used to tell when a newer one exists. |
| `~/.local/state/sobarch/skel-baseline/` | The baseline copy of each config file, for the three-way merge in [Updating Your Config](../../desktop/updating-system/). |
| `~/.local/state/sobarch/update-check/` | What the daily check has already notified you about. |

## System files sobarch manages

These are written by first boot and are not reconciled like your
dotfiles, so edit them directly if you need to.

- `/etc/nftables.conf`, the firewall ruleset.
- `/etc/ssh/sshd_config.d/10-sobarch-no-root-login.conf`, only when SSH is enabled.
- `/etc/polkit-1/rules.d/46-sobarch-power.rules`, the power-action rule.
- `/etc/pacman.d/hooks/sobarch-aur-sync.hook`, the sync trigger, owned by the `sobarch-scripts` package.
