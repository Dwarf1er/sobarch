"""Turns a WizardState + HardwareInfo into the two real archinstall
config files (base.json, credentials.json), by editing the installer's
JSON templates as parsed JSON rather than by text substitution: several
of the required edits (dropping the rescue partition, shifting the
BTRFS partition's start, computing its exact byte size, appending
detected packages) are structural, not simple token replacement, so the
whole pass is done the same way once we're already parsing the JSON
anyway."""

import json
from dataclasses import dataclass
from pathlib import Path

from archinstall.lib.crypt import crypt_yescrypt

from hardware import HardwareInfo
from state import WizardState

ARCHINSTALL_DIR = Path(__file__).resolve().parent.parent / "archinstall"
BASE_JSON_TEMPLATE = ARCHINSTALL_DIR / "base.json"
CREDENTIALS_JSON_TEMPLATE = ARCHINSTALL_DIR / "credentials.json"

MIB = 1024 * 1024

# GPT's secondary header and partition table occupy the last 33 LBA
# sectors of the disk (33 * 512 = 16896 bytes). Reserving a full MiB
# here, the same alignment already used for every partition's start
# offset in base.json, is simpler than computing the exact tail and
# leaves comfortable room for it either way.
GPT_TRAILING_RESERVE_BYTES = MIB


class ConfigGenError(Exception):
    pass


@dataclass
class GeneratedConfig:
    base: dict
    credentials: dict
    rescue_partition_number: int | None


def _to_mib(size_or_start: dict) -> int:
    unit = size_or_start["unit"]
    value = int(size_or_start["value"])
    if unit == "MiB":
        return value
    if unit == "GiB":
        return value * 1024
    raise ConfigGenError(f"unexpected unit {unit!r} in base.json template")


def partition_device_path(disk_device: str, partition_number: int) -> str:
    """/dev/sda -> /dev/sda1, but /dev/nvme0n1 -> /dev/nvme0n1p1: any
    device path ending in a digit needs a "p" separator before the
    partition number, or the kernel-assigned name would be ambiguous."""
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
    btrfs = next(p for p in partitions if p.get("fs_type") == "btrfs")

    boot_end_mib = _to_mib(boot["start"]) + _to_mib(boot["size"])
    rescue_partition_number = None

    if state.rescue_media:
        if rescue is None:
            raise ConfigGenError("rescue media was requested but base.json has no rescue partition template")
        btrfs_start_mib = boot_end_mib + _to_mib(rescue["size"])
        rescue_partition_number = partitions.index(rescue) + 1
    else:
        if rescue is not None:
            partitions.remove(rescue)
        btrfs_start_mib = boot_end_mib

    btrfs["start"] = {
        "sector_size": btrfs["start"]["sector_size"],
        "unit": "MiB",
        "value": btrfs_start_mib,
    }

    root_size_bytes = state.disk_size_bytes - (btrfs_start_mib * MIB) - GPT_TRAILING_RESERVE_BYTES
    if root_size_bytes <= 0:
        raise ConfigGenError("the selected disk is too small for this partition layout")

    btrfs["size"] = {
        "sector_size": btrfs["size"]["sector_size"],
        "unit": "B",
        "value": root_size_bytes,
    }

    base["hostname"] = state.hostname
    base["locale_config"]["kb_layout"] = state.kb_layout
    base["locale_config"]["sys_lang"] = state.sys_lang
    base["timezone"] = state.timezone
    base["app_config"]["bluetooth_config"]["enabled"] = hardware.bluetooth_detected

    extra_packages = {pkg for pkg in (hardware.cpu_microcode_pkg, *hardware.gpu_packages) if pkg}
    base["packages"] = sorted(set(base["packages"]) | extra_packages)

    credentials["users"][0]["username"] = state.username
    credentials["users"][0]["enc_password"] = crypt_yescrypt(state.password)

    return GeneratedConfig(
        base=base,
        credentials=credentials,
        rescue_partition_number=rescue_partition_number,
    )


def write_configs(generated: GeneratedConfig, out_dir: Path) -> tuple[Path, Path]:
    out_dir.mkdir(parents=True, exist_ok=True)
    base_path = out_dir / "base.json"
    credentials_path = out_dir / "credentials.json"
    base_path.write_text(json.dumps(generated.base, indent=4) + "\n")
    credentials_path.write_text(json.dumps(generated.credentials, indent=4) + "\n")
    return base_path, credentials_path
