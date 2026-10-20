# Contributing

Sobarch is a small independent project, and contributions are welcome:
bug reports, fixes, docs, and hardware test reports.

## Before you start

For anything beyond a small fix, open an issue first so we can agree on
the approach. The project deliberately keeps its tooling small: no
templating engines, no JSON/jq dependencies, no new toolchains on the live
ISO, and no feature without a reason. A change that adds a dependency or
a daemon needs a justification.

`PLAN.md` lists what is planned, `docs/DECISIONS.md` records why things
are the way they are, and `AGENTS.md` is a quick map of the repository.

## Setup

```sh
git clone git@github.com:Dwarf1er/sobarch.git
cd sobarch
scripts/install-git-hooks.sh   # once per clone
```

The hook validates `packages/custom/` PKGBUILDs before each commit and
bumps a package's version when its payload changed (requires `makepkg`).

Try the installer without installing anything:

```sh
python3 installer/tui/__main__.py --dry-run
```

## Making a change

- Configs under `skel/` and scripts under `installer/firstboot/` ship as
  packages. A change there bumps the matching package version; the hook
  does it for you.
- Vendored AUR packages under `packages/aur/` are updated by the weekly
  workflow's pull requests, not by hand.
- Keep code comments short and rare. Match the style of the file you are
  editing.
- User-facing behavior changes belong in `website/content/docs/`.
- Commit messages follow `type: summary`, such as `fix: waybar css
  whitespace` or `feat: add doctor command`.

## Reporting a bug

Run `sobarch doctor --write` and attach the file; it redacts hostname,
username, IP addresses and serial numbers, but read it before posting.
Security problems go through [SECURITY.md](SECURITY.md), not a public
issue.
