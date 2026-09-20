+++
title = "Disk & Account Setup"
description = "What the TUI asks for, and how to run or test it outside a real install."
weight = 10
template = "docs/page.html"

[extra]
lead = "The installer is a plain Python TUI (python-textual) that walks disk, account, and locale setup before handing off to archinstall."
toc = true
+++

The TUI walks through:

- Disk selection: wipes and partitions the entire target disk by
  default, or installs into existing free space instead for
  [dual-boot](../dual-boot/) alongside another OS
- Hostname, keyboard layout, system language, and timezone
- User account and password
- An optional SSH toggle
- Optional [software profiles](../software-profiles/)
- A review screen before anything is written to disk

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

`--dry-run` walks every prompt and generates the resulting
`archinstall` configuration, but the review screen only offers saving
it, never installing. Without the flag, "Install now" is also offered,
but only when running as root, since partitioning a real disk needs
it. Either way, "Save configuration" writes `base.json` and
`credentials.json` to `--output-dir` (default: `/root/sobarch-install`
as root, `./sobarch-install-output` otherwise) so you can inspect the
generated config.
