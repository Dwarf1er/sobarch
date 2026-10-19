#!/usr/bin/env python3
"""Lists the base-required packages for the ISO package cache.

Usage: list-packages.py --official | --aur
"""

import argparse
import json
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent

BASE_JSON = REPO_ROOT / "installer" / "archinstall" / "base.json"
BASE_AUR_PACKAGES_FILE = REPO_ROOT / "scripts" / "aur-sync" / "base-required-packages.txt"

# Always built by the installer, independent of base-required-packages.txt.
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
