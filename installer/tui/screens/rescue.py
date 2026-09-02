from textual.app import ComposeResult
from textual.containers import Horizontal, Vertical
from textual.widgets import Button, Static, Switch

from screens.base import WizardScreen

# Approximate, not live-fetched: the actual monthly ISO size drifts a
# little release to release, and this screen shouldn't gain a network
# dependency (and its failure mode) just to size a checkbox.
_APPROX_ISO_SIZE = "~1.5 GiB"
_APPROX_TIME_FAST = "~2 minutes on a 100 Mbps connection"
_APPROX_TIME_SLOW = "~20 minutes on a 10 Mbps connection"


class RescueScreen(WizardScreen):
    def compose(self) -> ComposeResult:
        state = self.sobarch_app.state
        with Vertical(classes="card"):
            yield Static("Rescue media", classes="card-title")
            yield Static(
                "Stores a full Arch ISO on its own disk partition, so this "
                "machine can boot straight into a rescue environment even "
                "with no other device around to write a USB drive. "
                "Recommended, but it adds a real download during install: "
                f"{_APPROX_ISO_SIZE} ({_APPROX_TIME_FAST}; "
                f"{_APPROX_TIME_SLOW}).",
                classes="card-subtitle",
            )

            with Horizontal():
                yield Switch(value=state.rescue_media, id="rescue-toggle")
                yield Static(" Include rescue media", classes="field-label")

            yield self.error_widget()
            with Horizontal(classes="button-row"):
                yield Button("Back", flat=True, id="back")
                yield Button("Continue", variant="primary", flat=True, id="continue")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "back":
            self.wizard_back()
            return

        rescue_media = self.query_one("#rescue-toggle", Switch).value
        self.wizard_continue({"rescue_media": rescue_media})
