import subprocess
from dataclasses import dataclass

from textual.app import ComposeResult
from textual.containers import Vertical
from textual.widgets import Input, Static

from disk_probe import DiskProbe, ExistingPartition, probe_disk
from disks import DiskInfo, list_disks
from sections.base import Section
from widgets import RadioList, Row, Toggle


@dataclass
class _Entry:
    disk: DiskInfo
    free_space_install: bool
    probe: DiskProbe | None
    partition: ExistingPartition | None = None


class DiskSection(Section):
    title = "Disk"
    required = True

    def compose(self) -> ComposeResult:
        state = self.sobarch_app.state
        yield Static(
            "The chosen disk is wiped and repartitioned. A disk with free space "
            "also offers a dual-boot entry that installs into that space only. "
            "On a T2 Mac, a partition made in macOS can be chosen instead: only that "
            "partition is replaced.",
            classes="note",
        )
        self._entries = self._build_entries()
        if not self._entries:
            yield Static("No disks detected.", classes="error")
        selected = next(
            (i for i, e in enumerate(self._entries) if self._matches_state(e, state)),
            None,
        )
        yield RadioList([self._label(e) for e in self._entries], selected=selected, id="disk-choice")

        yield Toggle("Encrypt the root partition (LUKS)", state.disk_encryption_enabled, id="encryption-toggle")
        with Vertical(id="encryption-fields"):
            yield Row("Passphrase", Input(password=True, value=state.disk_encryption_password, compact=True, id="encryption-password"))
            yield Row("Confirm", Input(password=True, value=state.disk_encryption_password, compact=True, id="encryption-password-confirm"))

    def on_mount(self) -> None:
        self._sync_encryption_fields()

    def on_toggle_changed(self, event: Toggle.Changed) -> None:
        self._sync_encryption_fields()

    def _sync_encryption_fields(self) -> None:
        self.query_one("#encryption-fields").display = self.query_one("#encryption-toggle", Toggle).value

    @staticmethod
    def _matches_state(entry: _Entry, state) -> bool:
        if entry.disk.path != state.disk_device or entry.free_space_install != state.free_space_install:
            return False
        return (entry.partition.device if entry.partition else None) == state.partition_device

    def _build_entries(self) -> list[_Entry]:
        # Free-space and partition installs are UEFI/GPT only.
        hardware = self.sobarch_app.get_hardware()
        is_uefi = hardware.is_uefi
        entries: list[_Entry] = []
        for disk in list_disks():
            entries.append(_Entry(disk=disk, free_space_install=False, probe=None))
            if not is_uefi:
                continue
            try:
                probe = probe_disk(disk.path)
            except (subprocess.CalledProcessError, OSError):
                # Unprobeable (e.g. not root): wipe-the-disk entry only.
                continue
            if probe.has_gpt and probe.free_space is not None:
                entries.append(_Entry(disk=disk, free_space_install=True, probe=probe))
            if probe.has_gpt and hardware.is_t2_mac:
                entries.extend(
                    _Entry(disk=disk, free_space_install=False, probe=probe, partition=partition)
                    for partition in probe.replaceable
                )
        return entries

    def _label(self, entry: _Entry) -> str:
        base = f"{entry.disk.path}  ({entry.disk.model}, {entry.disk.size_human}{', removable' if entry.disk.removable else ''})"
        if entry.partition is not None:
            part = entry.partition
            label = f' "{part.label}"' if part.label else ""
            return f"{base}, replace {part.device}{label} ({part.fstype or 'no filesystem'}, {part.size_bytes / 1024**3:.1f} GiB)"
        if not entry.free_space_install:
            return base
        assert entry.probe is not None and entry.probe.free_space is not None
        free_gib = entry.probe.free_space.size_bytes / 1024**3
        return f"{base}, dual-boot into {free_gib:.1f} GiB free space"

    def validate(self) -> str | None:
        if self.query_one("#disk-choice", RadioList).chosen is None:
            return "Choose a disk."
        if self.query_one("#encryption-toggle", Toggle).value:
            password = self.query_one("#encryption-password", Input).value
            if not password:
                return "Encryption passphrase cannot be empty."
            if password != self.query_one("#encryption-password-confirm", Input).value:
                return "Encryption passphrases do not match."
        return None

    def collect(self) -> None:
        state = self.sobarch_app.state
        index = self.query_one("#disk-choice", RadioList).chosen
        encrypt = self.query_one("#encryption-toggle", Toggle).value
        password = self.query_one("#encryption-password", Input).value
        matching = password == self.query_one("#encryption-password-confirm", Input).value
        state.disk_encryption_enabled = encrypt
        state.disk_encryption_password = password if encrypt and matching else ""

        if index is None:
            state.disk_device = None
            state.disk_size_bytes = None
            state.free_space_install = False
            state.partition_install = False
            state.partition_device = None
            return

        entry = self._entries[index]
        state.disk_device = entry.disk.path
        state.disk_size_bytes = entry.disk.size_bytes
        state.free_space_install = entry.free_space_install
        state.partition_install = entry.partition is not None
        state.partition_device = entry.partition.device if entry.partition else None

        if entry.partition is not None:
            state.free_space_start_bytes = entry.partition.start_bytes
            state.free_space_size_bytes = entry.partition.size_bytes
            state.free_space_at_disk_end = False
            state.rescue_media = False
            return
        if not entry.free_space_install:
            return

        assert entry.probe is not None and entry.probe.free_space is not None
        free_space = entry.probe.free_space
        state.free_space_start_bytes = free_space.start_bytes
        state.free_space_size_bytes = free_space.size_bytes
        state.free_space_at_disk_end = free_space.at_disk_end
        # No rescue media on a shared disk; OptionsSection enforces it.
        state.rescue_media = False
