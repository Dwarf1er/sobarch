"""Builds base.json and credentials.json from the archinstall templates.

The templates are edited as parsed JSON because the partition edits are structural.
"""

import json
import os
from dataclasses import dataclass
from pathlib import Path

from archinstall.lib.crypt import crypt_yescrypt

from hardware import HardwareInfo
from profiles_data import resolve_selection, split_by_source
from state import WizardState

ARCHINSTALL_DIR = Path(__file__).resolve().parent.parent / "archinstall"
BASE_JSON_TEMPLATE = ARCHINSTALL_DIR / "base.json"
CREDENTIALS_JSON_TEMPLATE = ARCHINSTALL_DIR / "credentials.json"

MIB = 1024 * 1024

# Room for the backup GPT in the last 33 sectors, rounded up to the MiB alignment.
GPT_TRAILING_RESERVE_BYTES = MIB


class ConfigGenError(Exception):
    pass


@dataclass
class GeneratedConfig:
    base: dict
    credentials: dict
    rescue_partition_number: int | None
    rescue_boot_partition_number: int | None
    rescue_boot_merged: bool


def _to_mib(size_or_start: dict) -> int:
    unit = size_or_start["unit"]
    value = int(size_or_start["value"])
    if unit == "MiB":
        return value
    if unit == "GiB":
        return value * 1024
    raise ConfigGenError(f"unexpected unit {unit!r} in base.json template")


def _mib_dict(template: dict, value_mib: int) -> dict:
    return {
        "sector_size": template["sector_size"],
        "unit": "MiB",
        "value": value_mib,
    }


def partition_device_path(disk_device: str, partition_number: int) -> str:
    """/dev/sda -> /dev/sda1, /dev/nvme0n1 -> /dev/nvme0n1p1."""
    if disk_device[-1].isdigit():
        return f"{disk_device}p{partition_number}"
    return f"{disk_device}{partition_number}"


def generate_configs(state: WizardState, hardware: HardwareInfo) -> GeneratedConfig:
    if not state.disk_device or state.disk_size_bytes is None:
        raise ConfigGenError("a disk must be selected before generating a config")

    base = json.loads(BASE_JSON_TEMPLATE.read_text())
    credentials = json.loads(CREDENTIALS_JSON_TEMPLATE.read_text())

    device_mod = base["disk_config"]["device_modifications"][0]
    device_mod["device"] = state.disk_device
    partitions = device_mod["partitions"]

    boot = next(p for p in partitions if "boot" in p.get("flags", []))
    rescue = next((p for p in partitions if p.get("fs_type") == "ext4"), None)
    # The rescue kernel's FAT32 partition: the one without the boot flag.
    rescue_boot = next(
        (p for p in partitions if p.get("fs_type") == "fat32" and "boot" not in p.get("flags", [])), None
    )
    btrfs = next(p for p in partitions if p.get("fs_type") == "btrfs")

    rescue_partition_number = None
    rescue_boot_partition_number = None
    rescue_boot_merged = False

    if state.free_space_install:
        # Never wipe or shrink anything. Rescue media is always off on this path.
        if rescue is not None:
            partitions.remove(rescue)
        if rescue_boot is not None:
            partitions.remove(rescue_boot)

        device_mod["wipe"] = False
        assert state.free_space_start_bytes is not None and state.free_space_size_bytes is not None
        # Round inward so an unaligned gap edge never overlaps a neighbour.
        free_space_start_mib = -(-state.free_space_start_bytes // MIB)
        free_space_end_mib = (state.free_space_start_bytes + state.free_space_size_bytes) // MIB

        # Own ESP, never the other OS's: /boot is the ESP and a small Windows ESP
        # would fill up, and Limine would overwrite its EFI/BOOT/BOOTX64.EFI.
        boot["start"] = _mib_dict(boot["start"], free_space_start_mib)
        btrfs_start_mib = free_space_start_mib + _to_mib(boot["size"])

        root_size_mib = free_space_end_mib - btrfs_start_mib
        if state.free_space_at_disk_end:
            root_size_mib -= GPT_TRAILING_RESERVE_BYTES // MIB
    else:
        boot_end_mib = _to_mib(boot["start"]) + _to_mib(boot["size"])

        if state.rescue_media:
            if rescue is None or rescue_boot is None:
                raise ConfigGenError("rescue media was requested but base.json has no rescue partition template")
            if hardware.is_uefi:
                btrfs_start_mib = boot_end_mib + _to_mib(rescue_boot["size"]) + _to_mib(rescue["size"])
                rescue_boot_partition_number = partitions.index(rescue_boot) + 1
                rescue_partition_number = partitions.index(rescue) + 1
            else:
                # BIOS installs use MBR with a 3 primary partition cap, so the
                # rescue kernel goes in /boot/rescue/ instead of its own partition.
                partitions.remove(rescue_boot)
                rescue["start"] = _mib_dict(rescue["start"], boot_end_mib)
                btrfs_start_mib = boot_end_mib + _to_mib(rescue["size"])
                rescue_partition_number = partitions.index(rescue) + 1
                rescue_boot_merged = True
        else:
            if rescue is not None:
                partitions.remove(rescue)
            if rescue_boot is not None:
                partitions.remove(rescue_boot)
            btrfs_start_mib = boot_end_mib

        root_size_mib = (state.disk_size_bytes - (btrfs_start_mib * MIB) - GPT_TRAILING_RESERVE_BYTES) // MIB

    if root_size_mib <= 0:
        raise ConfigGenError("the selected disk is too small for this partition layout")

    btrfs["start"] = _mib_dict(btrfs["start"], btrfs_start_mib)
    btrfs["size"] = _mib_dict(btrfs["size"], root_size_mib)

    if state.disk_encryption_enabled:
        # Root only, by obj_id since a new partition has no device path yet.
        # archinstall adds the initramfs hook and kernel parameter itself.
        base["disk_config"]["disk_encryption"] = {
            "encryption_type": "luks",
            "partitions": [btrfs["obj_id"]],
            "lvm_volumes": [],
        }
        # Plaintext; archinstall merges top-level keys from --creds, so it lives here.
        credentials["encryption_password"] = state.disk_encryption_password

    base["hostname"] = state.hostname
    base["locale_config"]["kb_layout"] = state.kb_layout
    base["locale_config"]["sys_lang"] = state.sys_lang
    base["timezone"] = state.timezone

    if state.mirror_regions:
        # archinstall re-fetches each region's URLs itself, so empty lists suffice.
        base["mirror_config"]["mirror_regions"] = {region: [] for region in state.mirror_regions}

    # Local repo baked into the prebuilt ISO only. Unsigned is fine since it never
    # leaves the image. archinstall also uses it for pacstrap.
    sobarch_cache_db = Path("/opt/sobarch-cache/sobarch-cache.db.tar.gz")
    if sobarch_cache_db.exists():
        base["mirror_config"]["custom_repositories"] = [
            {
                "name": "sobarch-cache",
                "url": "file:///opt/sobarch-cache",
                "sign_check": "Never",
                "sign_option": "TrustAll",
            }
        ]

    base["app_config"]["bluetooth_config"]["enabled"] = hardware.bluetooth_detected

    extra_packages = {pkg for pkg in (hardware.cpu_microcode_pkg, *hardware.gpu_packages, *hardware.laptop_packages) if pkg}
    base["packages"] = sorted(set(base["packages"]) | extra_packages)

    credentials["users"][0]["username"] = state.username
    # password_hash comes pre-hashed from an unattended answer file.
    credentials["users"][0]["enc_password"] = state.password_hash or crypt_yescrypt(state.password)

    return GeneratedConfig(
        base=base,
        credentials=credentials,
        rescue_partition_number=rescue_partition_number,
        rescue_boot_partition_number=rescue_boot_partition_number,
        rescue_boot_merged=rescue_boot_merged,
    )


def write_configs(generated: GeneratedConfig, out_dir: Path) -> tuple[Path, Path]:
    out_dir.mkdir(parents=True, exist_ok=True)
    base_path = out_dir / "base.json"
    credentials_path = out_dir / "credentials.json"
    base_path.write_text(json.dumps(generated.base, indent=4) + "\n")
    # May hold the LUKS passphrase: create it 0600, and chmod in case it already existed.
    fd = os.open(credentials_path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as credentials_file:
        credentials_file.write(json.dumps(generated.credentials, indent=4) + "\n")
    credentials_path.chmod(0o600)
    return base_path, credentials_path


def write_profile_selection(state: WizardState, out_dir: Path) -> Path:
    """Write the selected packages grouped by profile."""
    out_dir.mkdir(parents=True, exist_ok=True)
    path = out_dir / "profile-selection.json"
    selection = resolve_selection(state.install_everything, state.profile_packages)
    path.write_text(json.dumps(selection, indent=4) + "\n")
    return path


def write_firstboot_package_lists(state: WizardState, sobarch_dir: Path) -> tuple[Path, Path]:
    """Write flat official/AUR package lists for install-profile-packages.sh."""
    sobarch_dir.mkdir(parents=True, exist_ok=True)
    selection = resolve_selection(state.install_everything, state.profile_packages)
    all_selected = {pkg for packages in selection.values() for pkg in packages}
    official, aur = split_by_source(all_selected)

    official_path = sobarch_dir / "profile-packages-official.txt"
    aur_path = sobarch_dir / "profile-packages-aur.txt"
    official_path.write_text("".join(f"{pkg}\n" for pkg in official))
    aur_path.write_text("".join(f"{pkg}\n" for pkg in aur))
    return official_path, aur_path


def write_security_flags(state: WizardState, sobarch_dir: Path) -> Path:
    """Write the SSH true/false flag read by apply-security-baseline.sh."""
    sobarch_dir.mkdir(parents=True, exist_ok=True)
    path = sobarch_dir / "ssh-enabled"
    path.write_text("true\n" if state.ssh_enabled else "false\n")
    return path


def write_git_config(state: WizardState, sobarch_dir: Path) -> Path:
    """Write name and email for apply-git-setup.sh; blank lines skip git config."""
    sobarch_dir.mkdir(parents=True, exist_ok=True)
    path = sobarch_dir / "git-identity"
    path.write_text(f"{state.git_name}\n{state.git_email}\n")
    return path
