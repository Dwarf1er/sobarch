"""Small ratatui-flavoured building blocks shared by every section:
a one-line label+control row, a `[x]` toggle, and a single-choice list
marked with `(*)`. Plain Textual widgets underneath, restyled in
styles.tcss, so nothing new has to be installed on the live ISO."""

import time

from rich.text import Text
from textual import events
from textual.app import ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal
from textual.message import Message
from textual.widget import Widget
from textual.widgets import OptionList, SelectionList, Static
from textual.widgets.option_list import Option


class Row(Horizontal):
    """`Label        control` on one line."""

    def __init__(self, label: str, control: Widget, **kwargs) -> None:
        super().__init__(**kwargs)
        self._label = label
        self._control = control

    def compose(self) -> ComposeResult:
        yield Static(self._label, classes="row-label")
        yield self._control


class Toggle(Static, can_focus=True):
    """`[x] Label` checkbox. Space or Enter flips it."""

    BINDINGS = [
        Binding("space,enter", "toggle", "Toggle"),
    ]

    class Changed(Message):
        def __init__(self, toggle: "Toggle", value: bool) -> None:
            super().__init__()
            self.toggle = toggle
            self.value = value

    def __init__(self, label: str, value: bool = False, **kwargs) -> None:
        super().__init__(**kwargs)
        self._label = label
        self.value = value
        self._paint()

    def _paint(self) -> None:
        mark = "x" if self.value else " "
        self.update(Text.assemble(("[", "dim"), (mark, "bold"), ("] ", "dim"), self._label))

    def set_value(self, value: bool) -> None:
        self.value = value
        self._paint()

    def set_label(self, label: str) -> None:
        self._label = label
        self._paint()

    def action_toggle(self) -> None:
        self.set_value(not self.value)
        self.post_message(self.Changed(self, self.value))

    def on_click(self, event: events.Click) -> None:
        self.focus()
        self.action_toggle()


class RadioList(OptionList):
    """Single-choice list: the cursor is the highlight, `(*)` is the
    committed choice. Enter or click commits."""

    class Chosen(Message):
        def __init__(self, radio: "RadioList", index: int) -> None:
            super().__init__()
            self.radio = radio
            self.index = index

    def __init__(self, labels: list[str], selected: int | None = None, **kwargs) -> None:
        super().__init__(**kwargs)
        self._labels = labels
        self.chosen: int | None = selected

    def on_mount(self) -> None:
        self._render_options()
        self.highlighted = self.chosen if self.chosen is not None else 0

    def _render_options(self) -> None:
        highlighted = self.highlighted
        self.clear_options()
        self.add_options(
            [
                Option(Text.assemble(("(*) " if i == self.chosen else "( ) ", "bold" if i == self.chosen else "dim"), label))
                for i, label in enumerate(self._labels)
            ]
        )
        if highlighted is not None:
            self.highlighted = highlighted

    def on_option_list_option_selected(self, event: OptionList.OptionSelected) -> None:
        event.stop()
        self.chosen = event.option_index
        self._render_options()
        self.post_message(self.Chosen(self, event.option_index))


class TypeAheadSelectionList(SelectionList):
    """SelectionList where typing a name moves the cursor to the first
    entry starting with it (as the dropdowns already do). The buffer
    resets after a pause. Space keeps toggling, except mid-search, where
    it is part of the name ("United States")."""

    TYPE_AHEAD_TIMEOUT = 1.0

    def __init__(self, *args, **kwargs) -> None:
        super().__init__(*args, **kwargs)
        self._typed = ""
        self._typed_at = 0.0

    def _typing_in_progress(self) -> bool:
        return bool(self._typed) and time.monotonic() - self._typed_at < self.TYPE_AHEAD_TIMEOUT

    def on_key(self, event: events.Key) -> None:
        char = event.character
        if char is None or not char.isprintable():
            return
        if char == " " and not self._typing_in_progress():
            return  # plain space: let the toggle binding handle it

        event.stop()
        event.prevent_default()
        self._typed = (self._typed if self._typing_in_progress() else "") + char.lower()
        self._typed_at = time.monotonic()

        for index in range(self.option_count):
            option = self.get_option_at_index(index)
            if str(option.value).lower().startswith(self._typed):
                self.highlighted = index
                return
