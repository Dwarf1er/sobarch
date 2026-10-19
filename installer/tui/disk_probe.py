"""Finds free space in an existing GPT table for installing alongside another OS."""

import json
import subprocess
from dataclasses import dataclass

# Smallest gap worth offering for a free-space install.
MIN_FREE_SPACE_BYTES = 20 * 1024**3


@dataclass
class FreeSpaceRegion:
    start_bytes: int
    size_bytes: int
    # Only a gap at the end of the disk needs the backup GPT reserve.
    at_disk_end: bool


@dataclass
class DiskProbe:
    has_gpt: bool
    free_space: FreeSpaceRegion | None


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
        return DiskProbe(has_gpt=False, free_space=None)

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

    return DiskProbe(has_gpt=True, free_space=free_space)
