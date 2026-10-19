"""Runs installer/archinstall/hardware-detect.sh and parses its KEY=VALUE output."""

import shlex
import subprocess
from dataclasses import dataclass
from pathlib import Path

HARDWARE_DETECT_SCRIPT = Path(__file__).resolve().parent.parent / "archinstall" / "hardware-detect.sh"

# Same check as archinstall's SysInfo.has_uefi().
EFI_VARS_DIR = Path("/sys/firmware/efi")


@dataclass
class HardwareInfo:
    cpu_microcode_pkg: str
    gpu_vendors: list[str]
    gpu_packages: list[str]
    nvidia_present: bool
    nvidia_proprietary_driver: bool
    # Maxwell/Pascal/Volta: AUR nvidia-580xx-*, built after archinstall.
    nvidia_legacy_580xx: bool
    bluetooth_detected: bool
    is_laptop: bool
    laptop_packages: list[str]
    is_uefi: bool
    is_t2_mac: bool
    t2_packages: list[str]


def _parse_bool(value: str) -> bool:
    return value.strip().lower() == "true"


def detect_hardware(script_path: Path = HARDWARE_DETECT_SCRIPT) -> HardwareInfo:
    result = subprocess.run(
        ["bash", str(script_path)],
        capture_output=True,
        text=True,
        check=True,
    )

    values: dict[str, str] = {}
    for line in result.stdout.splitlines():
        line = line.strip()
        if not line or "=" not in line:
            continue
        # Split the whole assignment so a quoted value with spaces stays one token.
        tokens = shlex.split(line)
        if not tokens:
            continue
        key, _, unquoted_value = tokens[0].partition("=")
        values[key] = unquoted_value

    return HardwareInfo(
        cpu_microcode_pkg=values.get("CPU_MICROCODE_PKG", ""),
        gpu_vendors=values.get("GPU_VENDORS", "").split(),
        gpu_packages=values.get("GPU_PACKAGES", "").split(),
        nvidia_present=_parse_bool(values.get("NVIDIA_PRESENT", "false")),
        nvidia_proprietary_driver=_parse_bool(values.get("NVIDIA_PROPRIETARY_DRIVER", "false")),
        nvidia_legacy_580xx=_parse_bool(values.get("NVIDIA_LEGACY_580XX", "false")),
        bluetooth_detected=_parse_bool(values.get("BLUETOOTH_DETECTED", "false")),
        is_laptop=_parse_bool(values.get("IS_LAPTOP", "false")),
        laptop_packages=values.get("LAPTOP_PACKAGES", "").split(),
        is_uefi=EFI_VARS_DIR.is_dir(),
        is_t2_mac=_parse_bool(values.get("IS_T2_MAC", "false")),
        t2_packages=values.get("T2_PACKAGES", "").split(),
    )
