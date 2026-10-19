"""Finds free space and replaceable partitions in an existing GPT table, for installing alongside another OS."""

import json
import subprocess
from dataclasses import dataclass

# Smallest gap worth offering for a free-space install.
MIN_FREE_SPACE_BYTES = 20 * 1024**3

# GPT type GUIDs that are never offered as an install target.
_PROTECTED_TYPE_GUIDS = {
    "c12a7328-f81f-11d2-ba4b-00a0c93ec93b",  # EFI System Partition
    "7c3457ef-0000-11aa-aa11-00306543ecac",  # APFS container (macOS)
    "48465300-0000-11aa-aa11-00306543ecac",  # HFS+
    "426f6f74-0000-11aa-aa11-00306543ecac",  # Apple Boot (macOS Recovery)
    "53746f72-6167-11aa-aa11-00306543ecac",  # Apple Core Storage
    "e3c9e316-0b5c-4db8-817d-f92df00215ae",  # Microsoft Reserved
    "de94bba4-06d1-4d40-a16a-bfd50179d6ac",  # Windows Recovery
}


@dataclass
class FreeSpaceRegion:
    start_bytes: int
    size_bytes: int
    # Only a gap at the end of the disk needs the backup GPT reserve.
    at_disk_end: bool


@dataclass
class ExistingPartition:
    device: str
    start_bytes: int
    size_bytes: int
    fstype: str
    label: str


@dataclass
class DiskProbe:
    has_gpt: bool
    free_space: FreeSpaceRegion | None
    # Unmounted partitions of at least MIN_FREE_SPACE_BYTES that could be replaced.
    replaceable: list[ExistingPartition]


def probe_disk(path: str) -> DiskProbe:
    result = subprocess.run(
        ["sfdisk", "-J", path],
        capture_output=True,
        text=True,
        check=True,
    )
    table = json.loads(result.stdout)["partitiontable"]

    # Free-space installs on MBR are out of scope (see docs/DECISIONS.md).
    if table.get("label") != "gpt":
        return DiskProbe(has_gpt=False, free_space=None, replaceable=[])

    sector_size = table["sectorsize"]
    partitions = sorted(table.get("partitions", []), key=lambda p: p["start"])

    # lastlba is inclusive.
    disk_end_sector = table["lastlba"] + 1
    cursor = table["firstlba"]
    gaps: list[tuple[int, int]] = []
    for partition in partitions:
        if partition["start"] > cursor:
            gaps.append((cursor, partition["start"] - cursor))
        cursor = max(cursor, partition["start"] + partition["size"])
    if disk_end_sector > cursor:
        gaps.append((cursor, disk_end_sector - cursor))

    free_space = None
    if gaps:
        start_sector, size_sectors = max(gaps, key=lambda gap: gap[1])
        size_bytes = size_sectors * sector_size
        if size_bytes >= MIN_FREE_SPACE_BYTES:
            free_space = FreeSpaceRegion(
                start_bytes=start_sector * sector_size,
                size_bytes=size_bytes,
                at_disk_end=(start_sector + size_sectors == disk_end_sector),
            )

    return DiskProbe(
        has_gpt=True,
        free_space=free_space,
        replaceable=_replaceable_partitions(path, partitions, sector_size),
    )


def _replaceable_partitions(disk_path: str, partitions: list[dict], sector_size: int) -> list[ExistingPartition]:
    result = subprocess.run(
        ["lsblk", "-J", "-b", "-o", "PATH,FSTYPE,LABEL,MOUNTPOINTS", disk_path],
        capture_output=True,
        text=True,
        check=True,
    )
    children = {
        child["path"]: child
        for device in json.loads(result.stdout).get("blockdevices", [])
        for child in device.get("children") or []
    }

    candidates = []
    for partition in partitions:
        node = partition["node"]
        size_bytes = partition["size"] * sector_size
        if size_bytes < MIN_FREE_SPACE_BYTES:
            continue
        if partition.get("type", "").lower() in _PROTECTED_TYPE_GUIDS:
            continue
        info = children.get(node, {})
        if any(info.get("mountpoints") or []):
            continue
        fstype = info.get("fstype") or ""
        if fstype.startswith("apfs"):
            continue
        candidates.append(
            ExistingPartition(
                device=node,
                start_bytes=partition["start"] * sector_size,
                size_bytes=size_bytes,
                fstype=fstype,
                label=info.get("label") or "",
            )
        )
    return candidates
