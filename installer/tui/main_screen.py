"""The installer's one and only screen: a steps list on the left, the
active section's form on the right, a status block and a key-hint
footer below. Every section's widgets exist for the whole session, so
nothing is lost by moving between steps in any order."""

from rich.text import Text
from textual.app import ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal
from textual.screen import Screen
from textual.widgets import ContentSwitcher, Footer, OptionList, Static
from textual.widgets.option_list import Option

from network import is_connected
from sections.account import AccountSection
from sections.base import Section
from sections.disk import DiskSection
from sections.install import InstallSection
from sections.locale import LocaleSection
from sections.network import NetworkSection
from sections.options import OptionsSection
from sections.software import SoftwareSection

OK = ("✓", "green")
BAD = ("!", "red")
IDLE = ("·", "dim")


class MainScreen(Screen):
    BINDINGS = [
        Binding("tab", "app.focus_next", "Next field"),
        Binding("shift+tab", "app.focus_previous", "Prev field", show=False),
        Binding("ctrl+n", "step(1)", "Next step"),
        Binding("ctrl+p", "step(-1)", "Prev step"),
        Binding("escape", "focus_steps", "Steps"),
    ]

    def __init__(self) -> None:
        super().__init__()
        self._locked = False
        # Network is only offered when there is no connectivity at
        # startup; the answer is fixed for the session rather than
        # re-probed, so the steps list never shifts under the user.
        self._sections: list[Section] = []
        if not is_connected():
            self._sections.append(NetworkSection())
        self._sections += [
            DiskSection(),
            AccountSection(),
            LocaleSection(),
            OptionsSection(),
            SoftwareSection(),
            InstallSection(),
        ]
        for index, section in enumerate(self._sections):
            section.id = f"sec-{index}"
            section.border_title = section.title

    def compose(self) -> ComposeResult:
        app = self.app
        with Horizontal(id="titlebar"):
            yield Static(Text.assemble((" sobarch ", "bold reverse"), " installer"), id="title-left")
            mode = "UEFI" if app.get_hardware().is_uefi else "BIOS"  # type: ignore[attr-defined]
            if app.dry_run:  # type: ignore[attr-defined]
                mode += " · dry-run"
            yield Static(mode + " ", id="title-right")
        with Horizontal(id="body"):
            yield OptionList(*[Option(self._step_prompt(s, IDLE), id=s.id) for s in self._sections], id="steps")
            with ContentSwitcher(initial=self._sections[0].id, id="sections"):
                yield from self._sections
        yield Static("", id="status")
        yield Footer()

    def on_mount(self) -> None:
        steps = self.query_one("#steps", OptionList)
        steps.border_title = "Steps"
        self.query_one("#status").border_title = "Status"
        steps.highlighted = 0
        steps.focus()
        self.refresh_marks()

    # -- steps list -----------------------------------------------------

    @staticmethod
    def _step_prompt(section: Section, mark: tuple[str, str]) -> Text:
        return Text.assemble((f" {mark[0]} ", mark[1]), section.title)

    @property
    def _active(self) -> Section:
        return self.query_one(f"#{self.query_one('#sections', ContentSwitcher).current}", Section)

    def _mark(self, section: Section) -> tuple[str, str]:
        if section.validate():
            return BAD
        return IDLE if section.neutral() else OK

    def incomplete_steps(self) -> list[str]:
        return [s.title for s in self._sections if not isinstance(s, InstallSection) and s.validate()]

    def refresh_marks(self) -> None:
        for section in self._sections:
            section.collect()
        steps = self.query_one("#steps", OptionList)
        for section in self._sections:
            if isinstance(section, InstallSection):
                continue
            steps.replace_option_prompt(section.id, self._step_prompt(section, self._mark(section)))
        self._refresh_status()

    def _refresh_status(self) -> None:
        active = self._active
        status = self.query_one("#status", Static)
        if isinstance(active, InstallSection):
            problems = self.incomplete_steps()
            if problems:
                status.update(Text("✗ Incomplete: " + ", ".join(problems), style="red"))
            else:
                status.update(Text("✓ Everything needed is filled in.", style="green"))
            return
        reason = active.validate()
        status.update(Text("✗ " + reason, style="red") if reason else Text("✓ Ok", style="green"))

    def set_locked(self, locked: bool) -> None:
        """While the install runs, stepping elsewhere would only hide
        the log."""
        self._locked = locked
        self.query_one("#steps", OptionList).disabled = locked

    # -- events ---------------------------------------------------------

    def on_option_list_option_highlighted(self, event: OptionList.OptionHighlighted) -> None:
        if event.option_list.id != "steps" or self._locked or not event.option.id:
            return
        self.query_one("#sections", ContentSwitcher).current = event.option.id
        self._active.on_show()
        self.refresh_marks()

    def on_option_list_option_selected(self, event: OptionList.OptionSelected) -> None:
        if event.option_list.id == "steps":
            event.stop()
            self._focus_section()

    def _after_change(self, event) -> None:
        self.call_after_refresh(self.refresh_marks)

    on_input_changed = _after_change
    on_select_changed = _after_change
    on_toggle_changed = _after_change
    on_radio_list_chosen = _after_change
    on_selection_list_selected_changed = _after_change

    # -- actions --------------------------------------------------------

    def _focus_section(self) -> None:
        for widget in self._active.query("*"):
            if widget.focusable:
                widget.focus()
                return

    def action_focus_steps(self) -> None:
        if not self._locked:
            self.query_one("#steps", OptionList).focus()

    def action_step(self, delta: int) -> None:
        if self._locked:
            return
        steps = self.query_one("#steps", OptionList)
        current = steps.highlighted or 0
        target = max(0, min(len(self._sections) - 1, current + delta))
        steps.highlighted = target
        # Show the section now rather than waiting for the highlight
        # event, so its widgets are on screen when focus moves into it.
        self.query_one("#sections", ContentSwitcher).current = self._sections[target].id
        self.call_after_refresh(self._focus_section)
