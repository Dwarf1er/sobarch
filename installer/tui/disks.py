"""Real block device listing for the disk-selection screen, via lsblk
rather than /sys parsing, since lsblk already resolves model names and
whole-disk vs. partition distinctions correctly."""

import json
import subprocess
from dataclasses import dataclass

# zram (compressed swap in RAM) and loop devices are never valid
# install targets; excluded by name prefix rather than by absence of a
# "model" field, since some real disks also report no model.
_EXCLUDED_NAME_PREFIXES = ("zram", "loop")


@dataclass
class DiskInfo:
    path: str
    size_bytes: int
    model: str

    @property
    def size_human(self) -> str:
        size = float(self.size_bytes)
        for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
            if size < 1024 or unit == "TiB":
                return f"{size:.1f} {unit}"
            size /= 1024
        return f"{size:.1f} TiB"


def list_disks() -> list[DiskInfo]:
    result = subprocess.run(
        ["lsblk", "-J", "-b", "-d", "-o", "NAME,SIZE,MODEL,TYPE"],
        capture_output=True,
        text=True,
        check=True,
    )
    data = json.loads(result.stdout)

    disks = []
    for device in data.get("blockdevices", []):
        name = device.get("name", "")
        if device.get("type") != "disk":
            continue
        if name.startswith(_EXCLUDED_NAME_PREFIXES):
            continue
        disks.append(
            DiskInfo(
                path=f"/dev/{name}",
                size_bytes=int(device.get("size") or 0),
                model=(device.get("model") or "").strip() or "Unknown model",
            )
        )
    return disks
