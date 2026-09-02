"""Runs installer/archinstall/hardware-detect.sh and parses its
KEY=VALUE stdout, rather than reimplementing detection logic the shell
script already owns."""

import shlex
import subprocess
from dataclasses import dataclass
from pathlib import Path

HARDWARE_DETECT_SCRIPT = Path(__file__).resolve().parent.parent / "archinstall" / "hardware-detect.sh"


@dataclass
class HardwareInfo:
    cpu_microcode_pkg: str
    gpu_vendors: list[str]
    gpu_packages: list[str]
    nvidia_present: bool
    nvidia_proprietary_driver: bool
    bluetooth_detected: bool


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
        # shlex.split on the whole "KEY=value" assignment, not just the
        # value half, so a quoted value containing spaces (e.g.
        # GPU_VENDORS="amd intel") is unquoted without being word-split.
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
        bluetooth_detected=_parse_bool(values.get("BLUETOOTH_DETECTED", "false")),
    )
