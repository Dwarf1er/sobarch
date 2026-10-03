+++
title = "Installing & Updating"
description = "How vendored packages get built, installed, and kept current."
weight = 20
template = "docs/page.html"

[extra]
lead = "A plain build-and-install script handles vendored packages, triggered automatically by the same pacman upgrade that updates everything else."
toc = true
+++

Vendored AUR and custom packages are built and installed with a plain
`git clone` + `makepkg -si` per package, the same thing an AUR helper
would do under the hood, just without the standing ability to build
*any* AUR package unreviewed.

## Installing one on demand

From the desktop: **Super → Sobarch → Install**. This flattens every
[software profile](../../installer/software-profiles/)'s packages into
one deduped, individually-installable list and installs whichever one
you pick: official-repo packages via `pacman`, AUR/custom packages
through the same sync mechanism described below.

## Staying up to date

There's no separate timer or background polling for vendored
packages. A pacman hook fires on every package upgrade
(`pacman -Syu`), re-running the sync script, which diffs pinned
package versions against what's actually installed and rebuilds
anything behind. In practice: a normal `pacman -Syu` keeps vendored
packages current the same way it keeps official ones current: a
package just doesn't get re-checked until some upgrade actually
happens.

For a one-click version of the whole thing, **Super → Sobarch →
Update System** runs `pacman -Syu`, then the same sync, then your
[config merge](../../desktop/updating-system/), with progress
notifications. Raw `pacman -Syu` keeps working unchanged.

A daily background check also notifies you when official-repo updates
or a new `sobarch-skel`/`sobarch-scripts` are pending; click the
notification to open **Update System**. It only looks, never installs,
and re-notifies at most weekly for an unchanged backlog.

From a terminal, `sobarch aur-sync` runs the same sync by hand (with
no arguments it updates what's already installed; with package names
it installs exactly those, from the vendored set only), and
`sobarch update` does the full system update described above.

If a vendored package fails to build or install during that
automatic sync, you get a critical desktop notification listing which
packages failed, since the hook runs without a terminal you'd
necessarily be watching. The full output stays in pacman's own log.
