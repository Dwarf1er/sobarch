"""Regenerates packages/custom/sobarch-skel/data/profiles.txt from
PROFILES in profiles_data.py, for setup-profile-menu.sh (plain bash,
run on an installed system with no Python present) to read.

Not run automatically by anything: there is no CI check enforcing the
two stay in sync (packages/custom/ gets no CI checks at all right now,
per this project's own 2026-09-05 call in Phase 12), so this must be
re-run by hand after editing PROFILES.
"""

from pathlib import Path

from profiles_data import PROFILES

OUTPUT = Path(__file__).resolve().parent.parent.parent / "packages/custom/sobarch-skel/data/profiles.txt"


def main() -> None:
    lines = []
    for profile in PROFILES:
        pkgs = ",".join(f"{pkg.name}:aur" if pkg.aur else pkg.name for pkg in profile.packages)
        lines.append(f"{profile.slug}|{profile.name}|{pkgs}")
    OUTPUT.write_text("\n".join(lines) + "\n")
    print(f"wrote {OUTPUT}")


if __name__ == "__main__":
    main()
