#!/usr/bin/env python3
"""Enumerates every package the prebuilt-ISO package cache needs to
build/cache, across the three sources that between them define the
full install-time package surface: installer/archinstall/base.json's
`packages` array (base-required, official only), profiles_data.py's
PROFILES (optional, mixed official/AUR), and
scripts/aur-sync/base-required-packages.txt (base-required AUR
packages). No existing script aggregates all three; profiles_data.py's
own all_packages()/split_by_source() already do the official/AUR split
for the PROFILES side, reused here rather than re-implemented.

Usage: list-packages.py --official | --aur
Prints one package name per line, sorted, deduplicated.
"""

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent

# profiles_data.py lives in installer/tui/ and is only importable with
# that directory on sys.path (normally done by installer/tui/__main__.py
# itself); this script is a standalone CI entry point outside that
# package, so it does the same insert by hand.
sys.path.insert(0, str(REPO_ROOT / "installer" / "tui"))

from profiles_data import all_packages, split_by_source  # noqa: E402

BASE_JSON = REPO_ROOT / "installer" / "archinstall" / "base.json"
BASE_AUR_PACKAGES_FILE = REPO_ROOT / "scripts" / "aur-sync" / "base-required-packages.txt"

# Built unconditionally on every install (install_runner.py's
# _build_and_install_base_packages), regardless of profile selection or
# base-required-packages.txt, so the ISO cache always carries them too.
ALWAYS_BUILT_PACKAGES = ("sobarch-skel", "sobarch-scripts", "sobarch-limine-snapshots")


def _read_base_aur_packages() -> set[str]:
    names = set()
    for line in BASE_AUR_PACKAGES_FILE.read_text().splitlines():
        line = line.split("#", 1)[0].strip()
        if line:
            names.add(line)
    return names


def official_packages() -> list[str]:
    base_official = set(json.loads(BASE_JSON.read_text())["packages"])
    profile_official, _ = split_by_source(set(all_packages()))
    return sorted(base_official | set(profile_official))


def aur_packages() -> list[str]:
    _, profile_aur = split_by_source(set(all_packages()))
    return sorted(_read_base_aur_packages() | set(profile_aur) | set(ALWAYS_BUILT_PACKAGES))


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
