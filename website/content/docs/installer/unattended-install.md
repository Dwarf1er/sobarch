+++
title = "Unattended Install"
description = "Skipping the interactive wizard with a JSON answer file."
weight = 60
template = "docs/page.html"

[extra]
lead = "Same install pipeline as the interactive wizard, driven by a file instead of a keyboard."
toc = true
+++

The installer can run with no prompts at all, driven by a JSON answer
file instead of the interactive TUI screens. This is the same
`archinstall`-driven pipeline either way: an unattended run generates
and applies the exact same config an interactive run would, it just
skips asking a human for it.

## Running it

    python3 installer/tui/__main__.py --answer-file answer.json

Add `--dry-run` to only generate and save the config (same as
"Save configuration" in the interactive wizard) without touching a
disk, and `--output-dir` to change where it's written. Since
`bootstrap.sh` forwards its own arguments through to the TUI, this also
works straight from the one-line install command:

    curl -fsSL http://installsobarch.antoinepoulin.com | bash -s -- --answer-file /path/to/answer.json

The answer file itself has to already be on the machine (e.g. staged
onto a USB stick, or fetched by hand with `curl` before running the
above) — there's no network fetch of it built in yet. That arrives with
PXE support, planned once sobarch has its own installer ISO to netboot.

## Answer file

See
[`installer/unattended-answer.example.json`](https://github.com/Dwarf1er/sobarch/blob/master/installer/unattended-answer.example.json)
for a complete example. Every field below is optional except `disk`,
`hostname`, `username`, and `password`.

| Field | Default | Notes |
|---|---|---|
| `disk` | *(required)* | `"largest"`, or an exact device path (e.g. `/dev/nvme0n1`). |
| `hostname` | *(required)* | Same validation as the interactive Account screen. |
| `username` | *(required)* | Same validation as the interactive Account screen. |
| `password` | *(required)* | Plaintext; hashed the same way the interactive wizard hashes it, before it ever reaches `archinstall`'s own config. |
| `kb_layout` | `"us"` | |
| `sys_lang` | `"en_US.UTF-8"` | |
| `timezone` | `"UTC"` | |
| `mirror_region` | `""` (automatic) | A country name from `archinstall`'s own mirror-status data. |
| `rescue_media` | `true` | |
| `ssh_enabled` | `false` | |
| `encryption_password` | `""` (disabled) | Plaintext; a non-empty value LUKS-encrypts the root (btrfs) partition and unlocks with this passphrase at boot. The ESP and any rescue-media partitions are never encrypted. |
| `git_name` / `git_email` | `""` | Both or neither. |
| `install_everything` | `false` | |
| `profiles` | `[]` | A list of profile slugs (`developer`, `gaming`, `creative`, `maker`, `virtualization`, `office`, `browsers-chat`, `system-tuning`, `input-method`). Each selected profile installs in full. |

## What's deliberately not supported yet

- **Dual-boot / free-space installs.** Only whole-disk installs are
  supported; `disk` always wipes the target. Reusing an existing EFI
  System Partition or a detected free-space gap (see
  [Dual-Boot](../dual-boot/)) involves judgment calls the interactive
  review screen exists for.
- **Per-package profile selection.** `profiles` selects whole profiles
  only, not individual packages within one.
- **Fetching the answer file over the network, or PXE.** Both are
  planned once sobarch has its own installer ISO to netboot.
