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

# Where the Arch live ISO mounts the medium it booted from; any disk
# carrying a partition mounted here is the installer's own USB/CD and is
# never a valid target.
_LIVE_MEDIUM_MOUNTS = ("/run/archiso/bootmnt", "/run/archiso/airootfs")


@dataclass
class DiskInfo:
    path: str
    size_bytes: int
    model: str
    removable: bool = False
    # One human-readable line per existing partition ("sda1  ntfs
    # \"Windows\"  476.0 GiB"), shown on the final confirmation so the
    # user sees what is on the disk they're about to modify.
    partitions: tuple[str, ...] = ()

    @property
    def size_human(self) -> str:
        size = float(self.size_bytes)
        for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
            if size < 1024 or unit == "TiB":
                return f"{size:.1f} {unit}"
            size /= 1024
        return f"{size:.1f} TiB"


def _mountpoints(device: dict) -> list[str]:
    points = [m for m in (device.get("mountpoints") or []) if m]
    for child in device.get("children") or []:
        points.extend(_mountpoints(child))
    return points


def _describe_partitions(device: dict) -> tuple[str, ...]:
    lines = []
    for child in device.get("children") or []:
        size = DiskInfo(path="", size_bytes=int(child.get("size") or 0), model="").size_human
        parts = [child.get("name", "?"), child.get("fstype") or "no filesystem"]
        if child.get("label"):
            parts.append(f'"{child["label"]}"')
        parts.append(size)
        lines.append("  ".join(parts))
    return tuple(lines)


def list_disks() -> list[DiskInfo]:
    result = subprocess.run(
        ["lsblk", "-J", "-b", "-o", "NAME,SIZE,MODEL,TYPE,RM,FSTYPE,LABEL,MOUNTPOINTS"],
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
        if any(point in _LIVE_MEDIUM_MOUNTS for point in _mountpoints(device)):
            continue
        disks.append(
            DiskInfo(
                path=f"/dev/{name}",
                size_bytes=int(device.get("size") or 0),
                model=(device.get("model") or "").strip() or "Unknown model",
                removable=device.get("rm") in (True, 1, "1"),
                partitions=_describe_partitions(device),
            )
        )
    return disks
