#!/usr/bin/env python3
"""Enumerates the packages the prebuilt-ISO package cache needs to
build/cache: base-required only, not any optional profile. A real CI
run measured the full every-profile cache at 3.25GB and still growing
before it even finished building, against GitHub's real 2GiB-per-
release-asset limit (confirmed against GitHub's own docs) -- pruning
that down to fit would gut most of the large profiles anyway (Steam's
multilib deps, Blender, OBS, LibreOffice, Brave are each sizeable on
their own), so decision #20 was revised to base-required-only rather
than spend real CI time/bandwidth building packages that just get
thrown away. See docs/DECISIONS.md decision #20's addendum.

Sources: installer/archinstall/base.json's `packages` array (official)
and scripts/aur-sync/base-required-packages.txt (AUR), plus the
packages installer/tui/install_runner.py always builds regardless of
base-required-packages.txt (sobarch-skel/sobarch-scripts/
sobarch-limine-snapshots).

Usage: list-packages.py --official | --aur
Prints one package name per line, sorted, deduplicated.
"""

import argparse
import json
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent

BASE_JSON = REPO_ROOT / "installer" / "archinstall" / "base.json"
BASE_AUR_PACKAGES_FILE = REPO_ROOT / "scripts" / "aur-sync" / "base-required-packages.txt"

# Built unconditionally on every install (install_runner.py's
# _build_and_install_base_packages), regardless of base-required-packages.txt,
# so the ISO cache always carries them too.
ALWAYS_BUILT_PACKAGES = ("sobarch-skel", "sobarch-scripts", "sobarch-limine-snapshots")


def _read_base_aur_packages() -> set[str]:
    names = set()
    for line in BASE_AUR_PACKAGES_FILE.read_text().splitlines():
        line = line.split("#", 1)[0].strip()
        if line:
            names.add(line)
    return names


def official_packages() -> list[str]:
    return sorted(json.loads(BASE_JSON.read_text())["packages"])


def aur_packages() -> list[str]:
    return sorted(_read_base_aur_packages() | set(ALWAYS_BUILT_PACKAGES))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--official", action="store_true", help="List official-repo package names.")
    group.add_argument("--aur", action="store_true", help="List packages/aur+packages/custom package names.")
    args = parser.parse_args()

    names = official_packages() if args.official else aur_packages()
    print("\n".join(names))


if __name__ == "__main__":
    main()
