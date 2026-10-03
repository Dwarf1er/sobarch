"""Small ratatui-flavoured building blocks shared by every section:
a one-line label+control row, a `[x]` toggle, and a single-choice list
marked with `(*)`. Plain Textual widgets underneath, restyled in
styles.tcss, so nothing new has to be installed on the live ISO."""

from rich.text import Text
from textual import events
from textual.app import ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal
from textual.message import Message
from textual.widget import Widget
from textual.widgets import OptionList, Static
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
