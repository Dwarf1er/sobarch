# Sobarch

A minimal, reproducible Arch Linux + Hyprland desktop setup: installer,
versioned configuration, and package tooling in one repo.

Sobarch started after managing a dotfiles repository that eventually grew into a pile of other scripts and features; OS-level tweaks, packages, configuration, installation, multi-machine hardware detection, etc. It came to a point where creating a small reproducible environment was less overhead than letting the dotfiles spaghetti grow. The goals are simple; minimalistic in all aspects, as close to upstream Arch as possible, no custom package repository, as little dependencies as possible and a minimal amount of custom tooling to help managing the project.

The distribution is primarily built for its maintainer, but it hopes to stay understandable and usable by others. The minimalistic approach and simplicity will hopefully be good enough as a base for others as well.


<!-- mtoc-start -->

* [Quickstart](#quickstart)
* [Installer](#installer)
* [Hardware Detection](#hardware-detection)
* [Snapshots](#snapshots)
* [Rescue Media](#rescue-media)
* [Documentation](#documentation)
* [License](#license)

<!-- mtoc-end -->

## Quickstart

Not available yet.

**Note:** the installer currently only supports full-disk installs. It
partitions and wipes the entire target disk, and dual/multi-boot
(installing alongside an existing OS) is not supported.

## Installer

`installer/archinstall/base.json` and `credentials.json` are not valid
input to `archinstall` as-is. The TUI must perform a plain text
substitution pass before invoking `archinstall --config base.json
--creds credentials.json --silent`, replacing each of the following
tokens:

| Token | Found in | Notes |
|---|---|---|
| `__DISK_DEVICE__` | `base.json` | The target disk chosen in the TUI (e.g. `/dev/nvme0n1`). |
| `__ROOT_PARTITION_SIZE_BYTES__` | `base.json` | Must be replaced with a raw integer (remove the surrounding quotes too), not another quoted string. |
| `__HOSTNAME__` | `base.json` | |
| `__KB_LAYOUT__` | `base.json` | e.g. `us` |
| `__SYS_LANG__` | `base.json` | e.g. `en_US.UTF-8` |
| `__TIMEZONE__` | `base.json` | e.g. `America/Montreal` |
| `__USERNAME__` | `credentials.json` | |
| `__ENC_PASSWORD__` | `credentials.json` | Must be replaced with a raw string; quotes can stay since this one *is* a string field. |
| `__BLUETOOTH_DETECTED__` | `base.json` | Must be replaced with a raw `true`/`false` (remove the surrounding quotes too), based on whether a Bluetooth adapter is actually detected. Drives `archinstall`'s own `bluetooth_config` app mechanism, which installs `bluez`/`bluez-utils` and enables `bluetooth.service` together. |

`base.json`'s disk layout also reserves a third, unmounted partition
for rescue media (see the [Rescue Media](#rescue-media) section below). If the user
opts out of it, the TUI must remove that partition entry entirely and
shift the BTRFS partition's `start` back down from 6145 MiB to 1025 MiB.

## Hardware Detection

`installer/archinstall/hardware-detect.sh` runs once, on the live ISO,
before `archinstall` is invoked. It prints plain shell variable
assignments for the TUI to consume:

- **CPU vendor** (`/proc/cpuinfo`) picks the right microcode package
  (`intel-ucode`/`amd-ucode`).
- **GPU vendor(s)** (`/sys/class/drm/card*/device`) pick the right
  `mesa`/`vulkan-*` packages. AMD and Intel are fully supported.
  NVIDIA is best-effort: three generation tiers are distinguished by
  PCI device ID (Turing/RTX 20xx+ gets `nvidia-open-dkms`,
  Maxwell/Pascal/Volta gets the pinned legacy `nvidia-580xx-dkms`
  branch, anything older falls back to `nouveau` rather than being
  left with no driver at all), matching Omarchy's and CachyOS's own
  install scripts. No NVIDIA hardware exists to verify this against
  directly.
- **Bluetooth adapter presence** (`/sys/class/bluetooth/`) drives
  `archinstall`'s own `bluetooth_config` mechanism (see the Installer
  section above).

`installer/archinstall/nvidia-setup.sh` handles what package
installation alone can't: enabling DRM modesetting, forcing early
module loading in the initramfs, removing the generic `kms` mkinitcpio
hook (needed only for the two proprietary NVIDIA tiers), and enabling
the NVIDIA suspend/hibernate services. `installer/archinstall/
nvidia.lua` is deployed to `~/.config/hypr/nvidia.lua` only when NVIDIA
is detected, keeping NVIDIA-specific Hyprland environment variables off
AMD/Intel systems entirely. Both run as the TUI's own step immediately
after `archinstall` finishes but before reboot, not via `archinstall`'s
own `custom_commands` (which runs before `/etc/fstab` is even written,
with no error handling, a real reliability risk this project avoids by
running its own separately-invoked, properly-checked step against the
already-completed, still-mounted install instead).

## Snapshots

Every install gets automatic BTRFS snapshots via Snapper + `snap-pac`,
almost entirely set up natively by `archinstall` itself (not custom
first-boot logic): package installs, `snapper create-config`, both
systemd timers, and a `grub-btrfsd` GRUB-integration drop-in all happen
as part of the same install run. `installer/archinstall/
snapper-setup.sh` (run alongside `nvidia-setup.sh`) only overrides the
retention preset (daily snapshots, 5 kept) for both root and home:
home is snapshotted too, since accidentally deleting or overwriting a
personal file is a real, common risk worth its own safety net, not
just package upgrades. Bounded disk usage doesn't rely on that count
alone, Snapper's own untouched `SPACE_LIMIT`/`FREE_LIMIT` settings mean
`snapper-cleanup.timer` (already enabled) prunes the oldest snapshots
of either config, beyond the normal retention if needed, whenever
actual free space drops below 20%.

Two subvolumes, `@snapshots` and `@home-snapshots`, exist specifically
so a full rollback of `@` can never wipe out its own snapshot history,
the Arch Wiki's own [documented
fix](https://wiki.archlinux.org/title/Snapper#Suggested_filesystem_layout)
for a well-known problem with the standard flat Arch layout.

Day to day recovery is `grub-btrfs`: reboot, pick an old snapshot
straight from the GRUB menu, inspect or recover a file, reboot back.
Nothing is touched or replaced. For the rarer case of wanting an old
snapshot to become the new permanent `@`, `scripts/snapshot-rollback.sh`
implements the Arch Wiki's [documented manual
procedure](https://wiki.archlinux.org/title/Snapper#Restoring_/_to_its_previous_snapshot),
not the `snapper rollback` subcommand, which the Wiki's own suggested
layout explicitly isn't meant to be used with (a guard at
`/usr/local/bin/snapper` also warns and requires typed confirmation
before letting `rollback` run at all, for anyone who tries it anyway).
It supports two modes: a live ISO or rescue chroot (the only one that
always works, even if the installed system can't boot at all), or
`--online`, running directly on the currently booted system with no
live ISO needed, since `fstab`'s `subvol=@` only resolves by name once,
at mount time, so the running system stays bound to its subvolume by
internal ID regardless of what the `@` directory entry gets renamed to
on a separate, secondary mount of the same volume. This approach was taken directly from [yabsnap](https://github.com/hirak99/yabsnap).

## Rescue Media

`base.json`'s disk layout reserves a dedicated, generously-sized ext4
partition (recommended by default, opt-out for anyone tight on disk
space) so `scripts/snapshot-rollback.sh`'s rescue mode has a full Arch
ISO available on local disk, with no separate USB device needed at all
if a machine can't boot. `installer/archinstall/rescue-iso-setup.sh`
(run alongside `nvidia-setup.sh`/`snapper-setup.sh`) fetches the
current monthly release from an official mirror, verifies its
checksum, formats the partition, writes the ISO to it, and adds a
permanent GRUB boot entry that loads the ISO's own bundled
`loopback.cfg`, the Arch Wiki's own [documented
recipe](https://wiki.archlinux.org/title/Multiboot_USB_drive#Using_GRUB_and_loopback_devices)
for booting an ISO file in place.

The stored ISO is refreshed manually only, never automatically: a
background download on every boot or update would be surprising and
wasteful, and a slightly outdated rescue ISO is still far better than
none at all.

## Documentation

## License

This software is licensed under the [MIT license](LICENSE)
