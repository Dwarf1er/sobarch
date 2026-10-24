"""Optional software profiles and their packages."""

from dataclasses import dataclass
from pathlib import Path

_CUSTOM_PACKAGES_DIR = Path(__file__).resolve().parent.parent.parent / "packages" / "custom"


@dataclass(frozen=True)
class Package:
    name: str
    # True for anything aur-sync.sh builds: packages/aur/ or packages/custom/.
    aur: bool = False

    @property
    def source_label(self) -> str:
        if not self.aur:
            return ""
        return "sobarch" if (_CUSTOM_PACKAGES_DIR / self.name).is_dir() else "AUR"


@dataclass(frozen=True)
class Profile:
    name: str
    slug: str
    packages: tuple[Package, ...]


def _pkgs(*names: str, aur: bool = False) -> tuple[Package, ...]:
    return tuple(Package(name, aur=aur) for name in names)


PROFILES: tuple[Profile, ...] = (
    # neovim is in base.json.
    Profile("Developer", "developer", _pkgs("docker", "docker-buildx", "docker-compose", "mise", "presenterm")),
    Profile(
        "Gaming",
        "gaming",
        _pkgs("gamescope", "lutris", "mangohud", "prismlauncher", "protontricks", "steam")
        + _pkgs("gale-bin", "protonup-qt-bin", aur=True),
    ),
    Profile(
        "Creative",
        "creative",
        _pkgs(
            "audacity",
            "calf",
            "deepfilternet-ladspa",
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
    Profile("Remote Access", "remote-access", _pkgs("rustdesk-bin", aur=True)),
    Profile("Virtualization", "virtualization", _pkgs("quickemu-git", "quickgui-bin", aur=True)),
    Profile("Office", "office", _pkgs("homebank", "libreoffice-fresh")),
    Profile(
        "Browsers & Chat",
        "browsers-chat",
        _pkgs("signal-desktop") + _pkgs("brave-origin-bin", "vesktop-bin", aur=True),
    ),
    Profile(
        "System Tuning",
        "system-tuning",
        _pkgs("ethtool", "lact", "nvtop", "smartmontools")
        + _pkgs("sobarch-via-udev", aur=True),
    ),
    Profile(
        "Printing",
        "printing",
        _pkgs("cups", "cups-filters", "cups-pdf"),
    ),
    Profile(
        "Input Method",
        "input-method",
        _pkgs("fcitx5", "fcitx5-configtool", "fcitx5-gtk", "fcitx5-hangul"),
    ),
)

_AUR_PACKAGE_NAMES: frozenset[str] = frozenset(
    pkg.name for profile in PROFILES for pkg in profile.packages if pkg.aur
)


def all_packages() -> list[str]:
    return sorted({pkg.name for profile in PROFILES for pkg in profile.packages})


def resolve_selection(install_everything: bool, profile_packages: dict[str, list[str]]) -> dict:
    """Map profile name to selected packages, expanding "install everything"."""
    if install_everything:
        return {profile.name: [pkg.name for pkg in profile.packages] for profile in PROFILES}
    return {name: packages for name, packages in profile_packages.items() if packages}


def split_by_source(package_names: set[str]) -> tuple[list[str], list[str]]:
    """Split package names into sorted (official, aur) lists."""
    official = sorted(name for name in package_names if name not in _AUR_PACKAGE_NAMES)
    aur = sorted(name for name in package_names if name in _AUR_PACKAGE_NAMES)
    return official, aur
