"""Optional software profiles and their packages. Not fixed: split,
merge, or rename an entry the moment it stops being a single coherent
idea for someone choosing it."""

from dataclasses import dataclass


@dataclass(frozen=True)
class Package:
    name: str
    # True for anything aur-sync.sh must build locally -- packages/aur/
    # (actually AUR-sourced) or packages/custom/ (this project's own,
    # e.g. sobarch-via-udev) alike, both handled identically by that
    # script. False only for a plain official-repo `pacman -S` package.
    aur: bool = False


@dataclass(frozen=True)
class Profile:
    name: str
    slug: str
    packages: tuple[Package, ...]


def _pkgs(*names: str, aur: bool = False) -> tuple[Package, ...]:
    return tuple(Package(name, aur=aur) for name in names)


PROFILES: tuple[Profile, ...] = (
    Profile("Developer", "developer", _pkgs("mise", "neovim", "presenterm")),
    Profile(
        "Gaming",
        "gaming",
        _pkgs("gamescope", "lutris", "mangohud", "prismlauncher", "protontricks", "steam")
        + _pkgs("protonup-qt-bin", aur=True),
    ),
    Profile(
        "Creative",
        "creative",
        _pkgs(
            "audacity",
            "calf",
            "easyeffects",
            "gimp",
            "inkscape",
            "lsp-plugins",
            "obs-studio",
            "shotcut",
        ),
    ),
    Profile(
        "Maker / 3D Printing",
        "maker",
        _pkgs("blender", "freecad") + _pkgs("orca-slicer-bin", aur=True),
    ),
    Profile("Virtualization", "virtualization", _pkgs("quickemu-git", "quickgui-bin", aur=True)),
    Profile("Office", "office", _pkgs("homebank", "libreoffice-fresh")),
    Profile(
        "Browsers & Chat",
        "browsers-chat",
        _pkgs("signal-desktop") + _pkgs("brave-origin-bin", "vesktop", aur=True),
    ),
    Profile(
        "System Tuning",
        "system-tuning",
        _pkgs("ethtool", "lact", "nvtop", "smartmontools", "tlp", "tlp-rdw")
        + _pkgs("sobarch-via-udev", aur=True),
    ),
)

_AUR_PACKAGE_NAMES: frozenset[str] = frozenset(
    pkg.name for profile in PROFILES for pkg in profile.packages if pkg.aur
)


def all_packages() -> list[str]:
    return sorted({pkg.name for profile in PROFILES for pkg in profile.packages})


def resolve_selection(install_everything: bool, profile_packages: dict[str, list[str]]) -> dict:
    """The final answer, in the shape written for later consumption
    (the review screen's save/install path): "install everything" is
    resolved to every profile at its full package list here, so a
    reader of the persisted selection never needs to special-case it."""
    if install_everything:
        return {profile.name: [pkg.name for pkg in profile.packages] for profile in PROFILES}
    return {name: packages for name, packages in profile_packages.items() if packages}


def split_by_source(package_names: set[str]) -> tuple[list[str], list[str]]:
    """Splits a flat set of selected package names into (official,
    aur), sorted: official packages are a plain `pacman -S` at first
    boot, the second bucket needs aur-sync.sh's local build mechanism
    (packages/aur/ or packages/custom/, see Package.aur above)."""
    official = sorted(name for name in package_names if name not in _AUR_PACKAGE_NAMES)
    aur = sorted(name for name in package_names if name in _AUR_PACKAGE_NAMES)
    return official, aur
