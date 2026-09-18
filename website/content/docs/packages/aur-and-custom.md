+++
title = "AUR & Custom Packages"
description = "No AUR helper is installed. Here's what runs instead."
weight = 10
template = "docs/page.html"

[extra]
lead = "AUR packages are vendored as reviewed PKGBUILD snapshots and built locally, rather than pulled through a general-purpose AUR helper."
toc = true
+++

Two kinds of non-official packages exist in this repo:

- **`packages/aur/`**: thin PKGBUILDs for genuinely upstream AUR
  packages sobarch depends on (things like `tinty-git`,
  `blesh-git`, `localsend-bin`).
- **`packages/custom/`**: sobarch's own bespoke packages
  (`sobarch-skel`, `sobarch-scripts`, `sobarch-limine-snapshots`,
  `sobarch-via-udev`), often packaging content that lives elsewhere in
  this same repo.

Both are built and installed the same way. There's no AUR helper
installed or required anywhere on the system. An AUR helper can build
arbitrary, unreviewed AUR packages on demand, which cuts against
sobarch's minimalism and security goals: every PKGBUILD that does end
up vendored here is reviewed and scanned before merge, not fetched and
built blind at install time.

Because Arch's official repositories evolve, packages vendored from
the AUR are periodically re-checked and migrated out once they
graduate to `extra`: vendoring is a means, not a commitment to stay
on the AUR forever.
