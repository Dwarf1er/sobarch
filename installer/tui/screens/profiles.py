from textual.app import ComposeResult
from textual.containers import Horizontal, Vertical
from textual.widgets import Button, SelectionList, Static

from screens.base import WizardScreen

# The current profile list. Not fixed: split, merge, or rename an
# entry here the moment it stops being a single coherent idea.
PROFILES = [
    "Developer",
    "Gaming",
    "Creative",
    "Maker / 3D Printing",
    "Virtualization",
    "Office",
    "Browsers & Chat",
    "System Tuning",
]


class ProfilesScreen(WizardScreen):
    def compose(self) -> ComposeResult:
        state = self.sobarch_app.state
        with Vertical(classes="card"):
            yield Static("Optional software profiles", classes="card-title")
            yield Static(
                "Optional, applied after first boot. Leave everything "
                "unchecked to keep the base install minimal.",
                classes="card-subtitle",
            )

            yield SelectionList(
                *[(profile, profile, profile in state.profiles) for profile in PROFILES],
                id="profiles",
            )

            yield self.error_widget()
            with Horizontal(classes="button-row"):
                yield Button("Back", flat=True, id="back")
                yield Button("Continue", variant="primary", flat=True, id="continue")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "back":
            self.wizard_back()
            return

        selected = list(self.query_one("#profiles", SelectionList).selected)
        self.wizard_continue({"profiles": selected})
