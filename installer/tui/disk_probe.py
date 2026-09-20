"""Detects an existing GPT partition table's free space and any
existing EFI System Partition (ESP), to support installing sobarch into
free space alongside another OS instead of wiping the whole disk (see
screens/disk.py). Parses `sfdisk -J`'s own JSON rather than sgdisk's or
parted's text output, and rather than a second `sfdisk -F` call for
free space specifically: one JSON source already carries everything
needed (each partition's start/size in sectors, plus the disk's
firstlba/lastlba) to compute every gap in Python directly."""

import json
import subprocess
from dataclasses import dataclass

# GPT partition type GUID for an EFI System Partition, fixed by the
# UEFI spec, not something sfdisk assigns arbitrarily.
ESP_TYPE_GUID = "C12A7328-F81F-11D2-BA4B-00A0C93EC93B"

# Below this, installing sobarch's full default package set alongside
# another OS isn't realistic, so the free-space install option simply
# isn't offered under this floor. One module constant, easy to retune.
MIN_FREE_SPACE_BYTES = 20 * 1024**3


@dataclass
class PartitionRef:
    path: str
    start_bytes: int
    size_bytes: int


@dataclass
class FreeSpaceRegion:
    start_bytes: int
    size_bytes: int
    # Whether this gap runs to the physical end of the disk: only then
    # does config_gen.py's GPT-tail reserve apply (a mid-disk gap, e.g.
    # between two Windows partitions, needs no such reserve at all).
    at_disk_end: bool


@dataclass
class DiskProbe:
    has_gpt: bool
    existing_esp: PartitionRef | None
    # The largest free gap on the disk, if any clears MIN_FREE_SPACE_BYTES.
    free_space: FreeSpaceRegion | None


def probe_disk(path: str) -> DiskProbe:
    result = subprocess.run(
        ["sfdisk", "-J", path],
        capture_output=True,
        text=True,
        check=True,
    )
    table = json.loads(result.stdout)["partitiontable"]

    # MBR/BIOS free-space installs are out of scope (see docs/DECISIONS.md):
    # BIOS already has a tight 3-primary-partition budget, and dual-boot
    # alongside an existing OS is overwhelmingly a UEFI+GPT scenario anyway.
    if table.get("label") != "gpt":
        return DiskProbe(has_gpt=False, existing_esp=None, free_space=None)

    sector_size = table["sectorsize"]
    partitions = sorted(table.get("partitions", []), key=lambda p: p["start"])

    existing_esp = None
    for partition in partitions:
        if partition.get("type", "").upper() == ESP_TYPE_GUID:
            existing_esp = PartitionRef(
                path=partition["node"],
                start_bytes=partition["start"] * sector_size,
                size_bytes=partition["size"] * sector_size,
            )
            break

    # Walk the sorted partition list, recording the gap before each one
    # and, at the end, the gap between the last partition and the last
    # usable sector (lastlba is inclusive, hence the +1 to get an
    # exclusive end boundary matching the gaps' own start+size math).
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

    return DiskProbe(has_gpt=True, existing_esp=existing_esp, free_space=free_space)
