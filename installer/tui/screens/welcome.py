from pathlib import Path

from textual.app import ComposeResult
from textual.containers import Horizontal, Vertical
from textual.widgets import Button, Static

from screens.base import WizardScreen

LOGO_PATH = Path(__file__).resolve().parent.parent / "assets" / "logo.txt"


class WelcomeScreen(WizardScreen):
    def compose(self) -> ComposeResult:
        with Vertical(classes="card"):
            yield Static(LOGO_PATH.read_text(), id="logo")
            yield Static(
                "A minimal, reproducible Arch Linux + Hyprland install.",
                classes="card-subtitle",
            )
            with Horizontal(classes="button-row"):
                yield Button("Quit", flat=True, id="quit")
                yield Button("Begin", variant="primary", flat=True, id="begin")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "begin":
            self.wizard_continue({})
        elif event.button.id == "quit":
            self.wizard_quit()
