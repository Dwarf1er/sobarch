"""Shared wizard-screen scaffolding: an inline error message and
Back/Continue navigation wired to the App's own step index rather than
the screen stack (see app.py's wizard_advance()/wizard_back(): a
dismissed screen is gone from the stack, so plain pop_screen() can't
be used to return to a previous wizard step)."""

from typing import TYPE_CHECKING

from textual.binding import Binding
from textual.screen import Screen
from textual.widgets import Static

if TYPE_CHECKING:
    from app import SobarchApp


class WizardScreen(Screen):
    """Base class for every step of the install wizard."""

    # Widgets that already bind left/right themselves (Input, RadioSet)
    # consume the key before it gets here, so this only ever reaches
    # widgets like Button that don't: mainly the Back/Continue row.
    BINDINGS = [
        Binding("left", "app.focus_previous", show=False),
        Binding("right", "app.focus_next", show=False),
    ]

    @property
    def sobarch_app(self) -> "SobarchApp":
        return self.app  # type: ignore[return-value]

    def error_widget(self) -> Static:
        return Static("", classes="error-message", id="error-message")

    def show_error(self, message: str) -> None:
        self.query_one("#error-message", Static).update(message)

    def clear_error(self) -> None:
        # Not every screen has anything to validate (WelcomeScreen has
        # no fields), so it's fine for this widget to be absent.
        for widget in self.query("#error-message"):
            widget.update("")

    def wizard_continue(self, updates: dict) -> None:
        self.clear_error()
        self.sobarch_app.wizard_advance(updates)

    def wizard_back(self) -> None:
        self.sobarch_app.wizard_back()

    def wizard_quit(self) -> None:
        self.sobarch_app.exit()
