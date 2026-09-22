from dataclasses import dataclass

from textual.app import ComposeResult
from textual.containers import Horizontal, Vertical
from textual.widgets import Button, Input, RadioButton, RadioSet, Static, Switch

from disk_probe import DiskProbe, probe_disk
from disks import DiskInfo, list_disks
from screens.base import WizardScreen


@dataclass
class _Entry:
    disk: DiskInfo
    free_space_install: bool
    probe: DiskProbe | None


class DiskScreen(WizardScreen):
    def compose(self) -> ComposeResult:
        with Vertical(classes="card"):
            yield Static("Select install disk", classes="card-title")
            yield Static(
                "By default the chosen disk is wiped and fully repartitioned. "
                "A disk with existing free space also offers a dual-boot option "
                "that installs into that space instead, leaving the rest of the "
                "disk untouched.",
                classes="card-subtitle",
            )

            self._entries = self._build_entries()
            with RadioSet(id="disk-choice"):
                if not self._entries:
                    yield Static("No disks detected.", classes="error-message")
                for entry in self._entries:
                    yield RadioButton(self._label(entry))

            state = self.sobarch_app.state
            with Horizontal(classes="encryption-toggle-row"):
                yield Switch(value=state.disk_encryption_enabled, id="encryption-toggle")
                yield Static(" Encrypt the root partition (LUKS)", classes="field-label")

            with Vertical(id="encryption-fields"):
                yield Static("Encryption passphrase", classes="field-label")
                yield Input(password=True, value=state.disk_encryption_password, id="encryption-password")

                yield Static("Confirm passphrase", classes="field-label")
                yield Input(password=True, value=state.disk_encryption_password, id="encryption-password-confirm")

            yield self.error_widget()
            with Horizontal(classes="button-row"):
                yield Button("Back", flat=True, id="back")
                yield Button("Continue", variant="primary", flat=True, id="continue")

    def on_mount(self) -> None:
        self._set_encryption_fields_visible(self.sobarch_app.state.disk_encryption_enabled)

    def on_switch_changed(self, event: Switch.Changed) -> None:
        if event.switch.id == "encryption-toggle":
            self._set_encryption_fields_visible(event.value)

    def _set_encryption_fields_visible(self, visible: bool) -> None:
        self.query_one("#encryption-fields", Vertical).display = visible

    def _build_entries(self) -> list[_Entry]:
        # Free-space installs are UEFI/GPT-only (see disk_probe.py), so
        # a BIOS machine, or a disk with no usable free space, only ever
        # gets the existing wipe-the-whole-disk entry -- no UI change
        # from before for the common single-OS case.
        is_uefi = self.sobarch_app.get_hardware().is_uefi
        entries: list[_Entry] = []
        for disk in list_disks():
            entries.append(_Entry(disk=disk, free_space_install=False, probe=None))
            if not is_uefi:
                continue
            probe = probe_disk(disk.path)
            if probe.has_gpt and probe.free_space is not None:
                entries.append(_Entry(disk=disk, free_space_install=True, probe=probe))
        return entries

    def _label(self, entry: _Entry) -> str:
        base = f"{entry.disk.path}  ({entry.disk.model}, {entry.disk.size_human})"
        if not entry.free_space_install:
            return base
        assert entry.probe is not None and entry.probe.free_space is not None
        free_gib = entry.probe.free_space.size_bytes / 1024**3
        return f"{base}, dual-boot into {free_gib:.1f} GiB free space"

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "back":
            self.wizard_back()
            return

        radio_set = self.query_one("#disk-choice", RadioSet)
        index = radio_set.pressed_index
        if index is None or index < 0 or not self._entries:
            self.show_error("Choose a disk to continue.")
            return

        encryption_enabled = self.query_one("#encryption-toggle", Switch).value
        encryption_password = self.query_one("#encryption-password", Input).value
        encryption_password_confirm = self.query_one("#encryption-password-confirm", Input).value
        if encryption_enabled:
            if not encryption_password:
                self.show_error("Encryption passphrase cannot be empty.")
                return
            if encryption_password != encryption_password_confirm:
                self.show_error("Encryption passphrases do not match.")
                return

        entry = self._entries[index]
        updates = {
            "disk_device": entry.disk.path,
            "disk_size_bytes": entry.disk.size_bytes,
            "free_space_install": entry.free_space_install,
            "disk_encryption_enabled": encryption_enabled,
            "disk_encryption_password": encryption_password if encryption_enabled else "",
        }
        if entry.free_space_install:
            assert entry.probe is not None
            free_space = entry.probe.free_space
            assert free_space is not None
            updates["free_space_start_bytes"] = free_space.start_bytes
            updates["free_space_size_bytes"] = free_space.size_bytes
            updates["free_space_at_disk_end"] = free_space.at_disk_end
            esp = entry.probe.existing_esp
            updates["existing_esp_path"] = esp.path if esp else None
            updates["existing_esp_start_bytes"] = esp.start_bytes if esp else None
            updates["existing_esp_size_bytes"] = esp.size_bytes if esp else None
            # Rescue media (extra partitions) is disabled for free-space
            # installs, to avoid partition-count/size-budget edge cases
            # on a disk that's already shared with another OS -- see
            # docs/DECISIONS.md. app.py's wizard_advance()/wizard_back()
            # skip RescueScreen accordingly.
            updates["rescue_media"] = False

        self.wizard_continue(updates)
