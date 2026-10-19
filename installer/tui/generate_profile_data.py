"""Regenerates sobarch-skel's data/profiles.txt from PROFILES for setup-profile-menu.sh.

Run by hand after editing PROFILES; nothing checks the two stay in sync.
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
