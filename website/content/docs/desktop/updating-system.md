+++
title = "Updating Your System"
description = "How dotfile updates get merged into your $HOME without clobbering your edits."
weight = 60
template = "docs/page.html"

[extra]
lead = "Config updates are merged with what's already in $HOME, not copied over it. The same mechanism runs on first boot and every time you ask for it later."
toc = true
+++

Sobarch's default dotfiles live in a package (`sobarch-skel`) rather
than being copied once and forgotten. Every time it's applied, whether
on first boot or whenever you ask for it afterward, it merges into
your `$HOME` using a three-way comparison for each file:

- **Your current copy** in `$HOME`
- **The baseline**, a record of what was applied last time
- **The new version** being deployed

A file merges automatically wherever only one side actually changed.
When both your copy and the new version changed the same file, that's
a genuine conflict: the new version is dropped next to it as
`<file>.sobarch-new`, and your real file is never touched.

## Running it yourself

From the desktop: **Super → Sobarch → Update System**. It brings the
whole system current in one run, with a progress notification
throughout:

1. `pacman -Syu` updates official packages.
2. The [package sync mechanism](../../packages/installing-updating/)
   updates vendored AUR/custom packages.
3. If `sobarch-skel` changed, [boot and login theming](../boot-theming/)
   is re-applied, so branding changes ship through this same command
   as config changes.
4. Your tinty templates are rebuilt and the merge described above
   runs, walking you through any conflicts interactively: **K**eep
   yours, **U**se the new version, view the **D**iff, **E**dit, or
   **S**kip for now.

You'll be asked to authenticate once for the package steps. If the
update fails (offline, or a package conflict that needs a terminal),
you get a notification saying which half failed, and the config merge
still runs against whatever is already installed. Running `pacman -Syu`
yourself from a terminal still works exactly as before; the pacman
hook keeps vendored packages current in that case too.

If you'd rather just revisit conflicts left over from a previous run
without re-checking everything else, use **Review Conflicts** instead.
It re-runs the same interactive walkthrough over whatever
`.sobarch-new` files are still sitting on disk.
