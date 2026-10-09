+++
title = "Installing & Updating"
description = "How vendored packages get built, installed, and kept current."
weight = 20
template = "docs/page.html"

[extra]
lead = "A plain build-and-install script handles vendored packages, triggered automatically by the same pacman upgrade that updates everything else."
toc = true
+++

Vendored AUR and custom packages are built with plain `makepkg` (as a
dedicated unprivileged `sobarch-build` user, never as root) and
installed with `pacman -U`, the same thing an AUR helper would do under
the hood, just without the standing ability to build *any* AUR package
unreviewed. The script fetches the current repository snapshot first, so
it always sees the packages as they are now.

## Installing one on demand

From the desktop: **Super → Sobarch → Install**. This flattens every
[software profile](../../installer/software-profiles/)'s packages into
one deduped, individually-installable list (anything already installed
is left out) and installs whichever one
you pick: official-repo packages via `pacman`, AUR/custom packages
through the same sync mechanism described below.

## Staying up to date

There's no separate timer for building vendored packages. A pacman
hook fires after every transaction that upgrades a package
(`pacman -Syu`, or any other upgrade), and starts the sync script as a
detached systemd unit, `sobarch-aur-sync`. It's detached because
pacman still holds its database lock while hooks run, so the sync has
to wait for your upgrade to finish before it can install anything. The
upgrade itself returns immediately; the sync carries on in the
background and notifies you if something goes wrong.

The sync diffs the versions pinned in the repository against what's
actually installed and rebuilds anything behind. It only ever touches
vendored packages that are already installed, so it never installs a
profile package you didn't pick. A second trigger while one sync is
still running simply waits its turn, and the hook does nothing inside
a chroot or when the sync script's own pacman calls fire it again.

One gap is accepted on purpose: a `pacman -Syu` that upgrades nothing
runs no transaction, so the hook doesn't fire. Vendored packages are
then rechecked on the next real upgrade or the next **Update System**
run.

For a one-click version of the whole thing, **Super → Sobarch →
Update System** runs `pacman -Syu`, then the same sync, then your
[config merge](../../desktop/updating-system/), with progress
notifications. Raw `pacman -Syu` keeps working unchanged.
Update System also installs any "every install" package (see
[AUR & Custom Packages](../aur-and-custom/)) that was added to the
distro after your system was installed, since the background sync
only updates what's already present.

## Update notifications

A daily background check (a systemd user timer, first run ten minutes
after login) notifies you when official-repo updates or a new
`sobarch-skel`/`sobarch-scripts` are pending; click the notification
to open **Update System**. It only looks, never installs, and
re-notifies at most weekly for an unchanged backlog. If you set up
[rescue media](../../installer/rescue-media/), the same check also
tells you when a newer Arch ISO than the one on the rescue partition
is available, and clicking that notification opens the refresh prompt. A failed or
offline check is treated as "unknown", never as "nothing to do".

## From a terminal

`sobarch aur-sync` runs the same sync by hand (with no arguments it
updates what's already installed; with package names it installs
exactly those, from the vendored set only), and `sobarch update` does
the full system update described above. See
[The sobarch Command](../../desktop/sobarch-command/) for the full
list.

## When a build fails

If a vendored package fails to build or install during the automatic
sync, you get a critical desktop notification listing which packages
failed, since the hook runs without a terminal you'd necessarily be
watching. The full output is in `/var/log/sobarch/aur-sync.log` and in
the journal under `sobarch-aur-sync`.
