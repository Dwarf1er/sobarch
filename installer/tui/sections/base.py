"""One section of the single-screen installer. Every section owns a
pane of widgets and reads/writes its slice of WizardState; the main
screen only ever asks it four things: does it apply right now, is it
valid, copy my widgets into the state, and refresh from the state."""

from typing import TYPE_CHECKING

from textual.containers import VerticalScroll

if TYPE_CHECKING:
    from app import SobarchApp


class Section(VerticalScroll):
    title = ""
    # Shown in the steps list; sections that can be left entirely alone
    # (everything has a sane default) never show as incomplete.
    required = False

    @property
    def sobarch_app(self) -> "SobarchApp":
        return self.app  # type: ignore[return-value]

    def applies(self) -> bool:
        return True

    def validate(self) -> str | None:
        """None when valid, otherwise a one-line reason."""
        return None

    def collect(self) -> None:
        """Copy widget values into WizardState (valid or not)."""

    def on_show(self) -> None:
        """Called when the section becomes the active one."""

    def neutral(self) -> bool:
        """True while the section is valid but nothing has been done in
        it yet, so the steps list shouldn't claim it is complete."""
        return False
