+++
title = "The sobarch Command"
description = "A small command line front end for the same actions the Sobarch menu runs."
weight = 70
template = "docs/page.html"

[extra]
lead = "Every action in the Sobarch submenu that makes sense outside the desktop is also a subcommand, so a terminal or an SSH session can do the same things the menus do."
toc = true
+++

`sobarch` is a thin dispatcher. It adds no logic of its own: each
subcommand runs the same script the matching menu entry runs, and asks
for administrator rights only where that script needs them. Run
`sobarch help` for the built-in summary.

| Command | What it does |
| --- | --- |
| `sobarch update` | The full system update: `pacman -Syu`, vendored AUR/custom packages, then config reconciliation. See [Updating Your System](../updating-system/). |
| `sobarch review-conflicts` | Walks through any `.sobarch-new` conflicts left by an earlier update, without updating anything. |
| `sobarch aur-sync [PKG...]` | With no arguments, updates the vendored AUR/custom packages you already have installed. With names, builds and installs exactly those. See [Installing & Updating](../../packages/installing-updating/). |
| `sobarch snapshot-restore [--yes] N` | Makes Snapper snapshot `N` your permanent root. It takes effect after a reboot. See [Snapshots](../../installer/snapshots/). |
| `sobarch rescue-refresh` | Re-fetches the Arch ISO onto the rescue partition. See [Rescue Media](../../installer/rescue-media/). |
| `sobarch help` | Shows the command list. |

An unknown command prints the usage text and exits with status 2.

## Privileges

`update` and `review-conflicts` must run as your own user, not through
`sudo`. They read and write your `$HOME`, and they ask for `sudo`
themselves when a step needs it.

`aur-sync`, `snapshot-restore`, and `rescue-refresh` need root and
escalate on their own: with `sudo` when you're at a terminal, and with
a graphical password prompt (`pkexec`) when they're launched from a
menu or notification.

## Menu and command parity

| Menu entry | Command it runs |
| --- | --- |
| Sobarch, Update System | `sobarch update --gui` |
| Sobarch, Review Conflicts | `sobarch review-conflicts --gui` |
| Sobarch, Install (an AUR package) | `sobarch aur-sync <package>` |
| Sobarch, Refresh Rescue ISO | `sobarch rescue-refresh` |
| Booted-snapshot notification | `sobarch snapshot-restore --yes N` |

`--gui` swaps the plain terminal prompts for fuzzel pickers and
desktop notifications. You normally never type it yourself; the plain
form is what you want in a terminal.
