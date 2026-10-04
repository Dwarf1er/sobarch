+++
title = "Disk & Account Setup"
description = "What the TUI asks for, and how to run or test it outside a real install."
weight = 10
template = "docs/page.html"

[extra]
lead = "The installer is a plain Python TUI (python-textual) with disk, account, and locale setup on one screen, before handing off to archinstall."
toc = true
+++

The TUI is one screen. A bordered **Steps** list on the left holds one
entry per step, and the selected step's form appears on the right, with
a status line below saying what, if anything, still needs fixing. The
steps are:

- **Network**: only shown when the machine has no connectivity at
  startup
- **Disk**: wipes and partitions the entire target disk by default, or
  installs into existing free space instead for
  [dual-boot](../dual-boot/) alongside another OS; also the optional
  LUKS encryption toggle and passphrase
- **Account**: hostname, username, and password
- **Locale**: keyboard layout, system language, timezone, and mirror
  regions (pick any number, or none to keep the live ISO's
  speed-ranked mirrors)
- **Options**: [rescue media](../rescue-media/), the optional SSH
  toggle, and an optional git name and email
- **Software**: optional [software profiles](../software-profiles/)
- **Install**: a summary of every choice, then **Save configuration**
  and **Install now**

Each step shows a mark in the list: a check once it's filled in, an
exclamation mark while it needs attention. Nothing is written to disk
until you confirm on the Install step.

### Keys

- **Up/Down** move between steps; **Enter** or **Tab** moves into the
  step's form, and **Esc** returns to the Steps list
- **Ctrl+N** / **Ctrl+P** jump to the next or previous step
- **Ctrl+Q** quits

## Running it without installing

The installer runs the same way on an ordinary dev machine as it does
on the live ISO, which is what makes iterating on it possible without a
VM or spare disk:

```sh
python3 installer/tui/__main__.py --dry-run
```

or, with no setup at all, via [uv](https://github.com/astral-sh/uv):

```sh
uv run installer/tui/__main__.py --dry-run
```

`--dry-run` lets you fill in every step and generates the resulting
`archinstall` configuration, but the Install step only offers saving
it, never installing. Without the flag, "Install now" is also offered,
but only when running as root, since partitioning a real disk needs
it. Choosing it asks for a second confirmation that names the disk
that will be modified. Either way, "Save configuration" writes `base.json` and
`credentials.json` to `--output-dir` (default: `/root/sobarch-install`
as root, `./sobarch-install-output` otherwise) so you can inspect the
generated config.
