from textual.app import ComposeResult
from textual.containers import Horizontal, Vertical
from textual.widgets import Button, RadioButton, RadioSet, Static

from disks import list_disks
from screens.base import WizardScreen


class DiskScreen(WizardScreen):
    def compose(self) -> ComposeResult:
        with Vertical(classes="card"):
            yield Static("Select install disk", classes="card-title")
            yield Static(
                "The chosen disk is wiped and fully repartitioned. "
                "Dual/multi-boot alongside an existing OS is not supported.",
                classes="card-subtitle",
            )

            self._disks = list_disks()
            with RadioSet(id="disk-choice"):
                if not self._disks:
                    yield Static("No disks detected.", classes="error-message")
                for disk in self._disks:
                    yield RadioButton(f"{disk.path}  ({disk.model}, {disk.size_human})")

            yield self.error_widget()
            with Horizontal(classes="button-row"):
                yield Button("Back", flat=True, id="back")
                yield Button("Continue", variant="primary", flat=True, id="continue")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "back":
            self.wizard_back()
            return

        radio_set = self.query_one("#disk-choice", RadioSet)
        index = radio_set.pressed_index
        if index is None or index < 0 or not self._disks:
            self.show_error("Choose a disk to continue.")
            return

        disk = self._disks[index]
        self.wizard_continue({"disk_device": disk.path, "disk_size_bytes": disk.size_bytes})
