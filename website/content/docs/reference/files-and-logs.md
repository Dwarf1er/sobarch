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
| `/run/lock/sobarch-aur-sync.lock` | Held by a running sync; a second one waits for it. Not a log, but it is what a hung-looking sync is waiting on. |
| `journalctl -u sobarch-firstboot-packages.service` (and `-security`, `-skel`, `-git`, `-rfkill`, `-rescue`) | The first-boot units. |
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
| `~/.local/state/sobarch/skel-version` | Skel deployment |
| `~/.local/state/sobarch/git-setup-done` | SSH key generation and git identity for your account |

## Flags and records

| Path | Contents |
| --- | --- |
| `/etc/sobarch/ssh-enabled` | `true` or `false`, written by the installer's SSH option. |
| `/etc/sobarch/profile-packages-official.txt`, `/etc/sobarch/profile-packages-aur.txt` | The optional packages picked during install, read by the first-boot package step. |
| `/etc/sobarch/rescue-pending` | Present until the first-boot rescue step has downloaded the rescue ISO, then removed. |
| `/etc/sobarch/git-identity` | The git identity entered during install, applied to your account at first boot. |
| `/var/lib/sobarch/rescue-iso-sha256` | Checksum of the ISO on the rescue partition, used to tell when a newer one exists. |
| `~/.local/state/sobarch/skel-baseline/` | The baseline copy of each config file, for the three-way merge in [Updating Your Config](../../desktop/updating-system/). |
| `~/.local/state/sobarch/update-check/` | What the daily check has already notified you about. |
| `~/.config/sobarch/` | Per-user sobarch state: the menu icons, `current-wallpaper` (the selected wallpaper), and the rendered tinty theme templates. |
| `*.sobarch-new` (next to the file it belongs to, under `$HOME`) | An unresolved config conflict left by a skel merge; resolve with `sobarch review-conflicts`. |

## Where the packages put things

| Path | Contents |
| --- | --- |
| `/usr/share/sobarch/skel/` | The pristine default config shipped by `sobarch-skel`, the "new" side of the three-way merge. |
| `/usr/share/sobarch/profiles.txt`, `/usr/share/sobarch/branding/` | The profile list the Install menu reads, and the logo and wordmark assets. |
| `/usr/local/lib/sobarch/` | The first-boot, sync, update, and theming scripts from `sobarch-scripts`. |
| `/usr/local/bin/sobarch` | The [`sobarch` command](../../desktop/sobarch-command/). |
| `/var/lib/sobarch-build/` | Home of the unprivileged `sobarch-build` user that builds vendored packages. Per-run build trees are temporary directories under `/var/tmp/sobarch-aur-sync-*`. |

## System files sobarch manages

These are written by first boot and are not reconciled like your
dotfiles, so edit them directly if you need to.

- `/etc/nftables.conf`, the firewall ruleset.
- `/etc/ssh/sshd_config.d/10-sobarch-no-root-login.conf`, only when SSH is enabled.
- `/etc/polkit-1/rules.d/46-sobarch-power.rules`, the power-action rule.
- `/etc/pam.d/ly` and `/etc/pam.d/ly-autologin`, edited to use `pam_oo7.so` instead of `pam_gnome_keyring.so`.
- `/etc/pacman.d/hooks/sobarch-aur-sync.hook`, the sync trigger, owned by the `sobarch-scripts` package.
- `/etc/NetworkManager/dispatcher.d/90-sobarch-firstboot`, which starts the network-dependent first-boot units, also owned by `sobarch-scripts`.
- `/etc/systemd/system/sobarch-firstboot-*.service`, the first-boot units, written by the installer with your username filled in.
- `/etc/xdg/mimeapps.list`, the system-wide default applications, owned by `sobarch-skel`; `~/.config/mimeapps.list` overrides it.
- `/usr/local/share/applications/vesktop.desktop`, the launcher override that routes Vesktop through its [integrity wrapper](../../packages/aur-and-custom/#how-the-vesktop-wrapper-is-installed), present only while both packages are installed.
- On a laptop, `tlp.service` and `tlp-pd.service` are enabled and `systemd-rfkill` is masked; see the [FAQ](../faq/).
