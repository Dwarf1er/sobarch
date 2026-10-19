"""Base class for one section of the single-screen installer."""

from typing import TYPE_CHECKING

from textual.containers import VerticalScroll

if TYPE_CHECKING:
    from app import SobarchApp


class Section(VerticalScroll):
    title = ""
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
        """True while valid but untouched, so it isn't marked complete."""
        return False
