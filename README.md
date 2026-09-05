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
* [First Boot](#first-boot)
* [Documentation](#documentation)
* [License](#license)

<!-- mtoc-end -->

## Quickstart

Boot the [official Arch Linux ISO](https://archlinux.org/download/),
connect to the network (`iwctl` for Wi-Fi; wired works out of the box),
then run:

    curl -fsSL https://raw.githubusercontent.com/Dwarf1er/sobarch/master/bootstrap.sh | bash

This is the only manually-typed, unbranded step.
`bootstrap.sh` fetches a checkout of this repository into a temp
directory and launches `installer/tui/__main__.py`, nothing else; no
separate hosting, no custom ISO. The TUI then walks through disk
selection, account/locale setup, and optional software profiles before
handing off to `archinstall`. On success it reboots into a working
desktop; on failure it points at the full install log rather than
hiding it behind a branded screen.

**Note:** the installer currently only supports full-disk installs. It
partitions and wipes the entire target disk, and dual/multi-boot
(installing alongside an existing OS) is not supported.

## Installer

`installer/archinstall/base.json` and `credentials.json` are not valid
input to `archinstall` as-is: they need each of the following tokens
replaced before `archinstall --config base.json --creds
credentials.json --silent` is invoked. `installer/tui/config_gen.py`
does this by parsing both files as JSON and editing them as data
(some of the required edits, like the rescue partition below, are
structural, not simple token replacement); the table exists as the
raw template's own contract, for anyone hand-running `archinstall`
against these files directly instead of through the TUI.

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

### Running and testing the TUI

`installer/tui/` is plain Python on `python-textual`, which
`archinstall` already depends on, so nothing extra needs installing on
the live ISO to run it there:

    python3 installer/tui/__main__.py --dry-run

It also runs the same way on an ordinary dev machine, not only from a
live ISO, which is what makes iterating on it without a VM or a spare
disk possible. `installer/tui/__main__.py` carries
[PEP 723](https://peps.python.org/pep-0723/) inline metadata, so
[uv](https://github.com/astral-sh/uv) can run it standalone, in its
own isolated environment, with no other setup:

    uv run installer/tui/__main__.py --dry-run

`--dry-run` walks every prompt and generates the resulting
`archinstall` config, but the review screen only offers saving it,
never installing (mirroring `archinstall`'s own `--dry-run`). Without
that flag, "Install now" is also offered, but only when running as
root, since partitioning a real disk needs it. Either way, "Save
configuration" writes `base.json`/`credentials.json` to `--output-dir`
(default: `/root/sobarch-install` as root, `./sobarch-install-output`
otherwise) for inspection.

The optional-profiles screen (`installer/tui/profiles_data.py` for the
package lists, `installer/tui/screens/profiles.py` for the screen
itself) offers "install everything" or, per profile, either taking it
whole or expanding it to hand-pick individual packages, per its two
selection levels. This choice isn't part of
`archinstall`'s own config at all: selected packages are deliberately
installed after first boot rather than during the install session, so
the base install itself stays fast and minimal, and every profile
installs the same way whether or not it happens to contain an AUR
package (`archinstall --silent` can only pacman-install official-repo
packages, so "some profiles ready immediately, others delayed" isn't
actually avoidable if any of it happened during install instead).
"Save configuration" and a real install both write `profile-selection.json`
(a human-readable, per-profile breakdown, for inspection) alongside
`base.json`/`credentials.json`.

The actual first-boot mechanism lives in `installer/firstboot/`:
`install-profile-packages.sh` reads two flat package lists
(`/etc/sobarch/profile-packages-{official,aur}.txt`, written by
`config_gen.write_firstboot_package_lists`), `pacman -S`s the
official-repo ones, and builds/installs the AUR ones via `aur-sync.sh`
(`scripts/aur-sync/`, decision 3's local vendored-package build
mechanism). `sobarch-firstboot-packages.service`, a
`ConditionPathExists`-guarded oneshot enabled by `install_runner.py`
right after `archinstall` finishes, runs that script once on first boot
and retries on the next boot if it fails (e.g. no network yet), rather
than being silently skipped.

The two AUR-only base-required packages (`localsend-bin`, `wlogout`;
decision 3) aren't deferred like the optional profiles above: they're
built and installed synchronously during the install session itself,
the same way `sobarch-skel` already is, so both exist before first boot
rather than waiting on the post-login network trigger the optional
profiles use. Ongoing updates for anything already installed
(`sobarch-skel`, the base AUR packages, or any installed profile AUR
package) are handled by a pacman hook on `Operation = Upgrade`
(`scripts/aur-sync/sobarch-aur-sync.hook`) that re-runs `aur-sync.sh`;
there's no separate timer or independent polling, so a package only
gets checked when some `pacman -Syu` actually upgrades something.

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
as part of the same install run. Snapshots are root-only: personal-file
backup is a distinct concern left to the user's own tools, not this
safety net. `archinstall` unconditionally creates a `home` Snapper
config too (hardcoded, no way to opt out from the JSON config), so
`installer/archinstall/snapper-setup.sh` (run alongside
`nvidia-setup.sh`) deletes it immediately, then overrides `root`'s
retention preset: daily snapshots, 5 kept, plus `snap-pac`'s
per-transaction limit lowered to 5 (from Snapper's stock 50). Bounded
disk usage doesn't rely on those counts alone, Snapper's own untouched
`SPACE_LIMIT`/`FREE_LIMIT` settings mean `snapper-cleanup.timer`
(already enabled) prunes the oldest snapshots beyond the normal
retention if needed, whenever actual free space drops below 20%.

The pacman cache and system logs live inside `@` rather than their own
subvolumes, matching the Arch Wiki's own suggested layout exactly; the
one subvolume that layout does call for, `@snapshots`, exists
specifically so a full rollback of `@` can never wipe out its own
snapshot history, the Arch Wiki's own [documented
fix](https://wiki.archlinux.org/title/Snapper#Suggested_filesystem_layout)
for a well-known problem with the standard flat Arch layout.

Day to day recovery is `grub-btrfs`: reboot, pick an old snapshot
straight from the GRUB menu, inspect or recover a file, reboot back.
Nothing is touched or replaced. For the rarer case of wanting an old
snapshot to become the new permanent `@`, `scripts/snapshot-rollback.sh`
implements the Arch Wiki's [documented manual
procedure](https://wiki.archlinux.org/title/Snapper#Restoring_/_to_its_previous_snapshot),
not the `snapper rollback` subcommand, which the Wiki's own suggested
layout explicitly isn't meant to be used with. It supports two modes: a live ISO or rescue chroot (the only one that
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

## First Boot

`installer/firstboot/` holds every first-boot unit; `install_runner.py`
deploys and enables all of them (`/usr/local/lib/sobarch/<script>` +
`/etc/systemd/system/<service>`) as its last step before unmounting the
target, each as its own `ConditionPathExists`-guarded oneshot that
retries on the next boot if it fails rather than being silently
skipped. `install-profile-packages.sh` (optional packages, see
Installer above) is one of three; the other two are new:

- **`apply-skel.sh`** / `sobarch-firstboot-skel.service` deploys
  `sobarch-skel`'s defaults into the new account's `$HOME`, using the
  three-way `diff3`-based reconciliation implemented below: for each file,
  compare the current
  `$HOME` copy, the recorded *baseline* (a snapshot of what was applied
  last, under `~/.local/state/sobarch/skel-baseline/`), and the *new*
  version, merging cleanly wherever only one side changed and dropping
  a `<file>.sobarch-new` (never touching the real file) on a genuine
  conflict. With no baseline recorded yet, first boot resolves every
  file to "take new" trivially: this is the mechanism's first
  invocation, not a separate copy path. `update-config-menu.sh`
  (not built yet, a fuzzel-driven script rather than a CLI command)
  later exposes this exact script, unmodified, as a keybind-triggered
  action, adding only its own interactive conflict walkthrough on top.
  Needs `-a`/`--text` on the
  `diff3` call: without it, `diff3` hard-fails outright on any binary
  skel file (the default wallpaper) even in the trivial no-baseline
  case, a real bug caught before shipping, not a theoretical one. Runs
  as the new account (`User=` in the unit, substituted in by
  `install_runner.py`), never as root, since it only ever writes inside
  that account's own `$HOME`.
- **`apply-security-baseline.sh`** / `sobarch-firstboot-security.service`
  implements the security baseline: writes
  `/etc/nftables.conf` (default-drop inbound, loopback and
  established/related always allowed, an exception for LocalSend's
  53317/tcp+udp), enables `nftables.service`, and locks the root
  account (`passwd -l root`) unconditionally. It also reads
  `/etc/sobarch/ssh-enabled` (written by `config_gen.write_security_flags`
  from the TUI's SSH screen, `installer/tui/screens/ssh.py`): when
  `true`, it installs `openssh`, drops in
  `/etc/ssh/sshd_config.d/10-sobarch-no-root-login.conf`
  (`PermitRootLogin no`), opens the matching firewall exception, and
  enables `sshd.service`; otherwise it defensively disables `sshd`.
  SSH is off by default and, like the other optional components, is a
  toggle in the TUI rather than a package-profile checkbox, since
  enabling it needs more than installing a package.

Since no vendored/local package build-and-sync mechanism exists yet
either, `install_runner.py`
also locally builds `packages/custom/sobarch-skel` from this checkout
and installs it into the target right after `archinstall` finishes, as
the newly created user (`makepkg` refuses outright to run as root, no
override flag), so `/usr/share/sobarch/skel/` and a real `pacman -Qi
sobarch-skel` both exist by the time `apply-skel.sh` needs them. This
is a minimal, one-off stand-in a future vendored-package mechanism
will supersede for keeping `sobarch-skel` current after install; this
step only needed *something* to get it installed the very first time.

## Documentation

## License

This software is licensed under the [MIT license](LICENSE)
