from textual.app import ComposeResult
from textual.containers import Horizontal, Vertical
from textual.widgets import Button, Select, Static

from screens.base import WizardScreen

DEFAULT_KB_LAYOUTS = ["us"]
DEFAULT_LOCALES = ["en_US.UTF-8"]
DEFAULT_TIMEZONES = ["UTC"]


def _list_kb_layouts() -> list[str]:
    try:
        from archinstall.lib.locale.utils import list_keyboard_languages

        return list_keyboard_languages() or DEFAULT_KB_LAYOUTS
    except Exception:
        return DEFAULT_KB_LAYOUTS


def _list_locales() -> list[str]:
    try:
        from archinstall.lib.locale.utils import list_locales

        # Each line is "en_US.UTF-8 UTF-8"; base.json's sys_lang only
        # wants the locale name, the first field.
        names = [line.split()[0] for line in list_locales() if line.strip()]
        return names or DEFAULT_LOCALES
    except Exception:
        return DEFAULT_LOCALES


def _list_timezones() -> list[str]:
    try:
        from archinstall.lib.locale.utils import list_timezones

        return list_timezones() or DEFAULT_TIMEZONES
    except Exception:
        return DEFAULT_TIMEZONES


class LocalizationScreen(WizardScreen):
    def compose(self) -> ComposeResult:
        state = self.sobarch_app.state
        with Vertical(classes="card"):
            yield Static("Locale and keyboard", classes="card-title")

            yield Static("Keyboard layout", classes="field-label")
            yield Select(
                [(layout, layout) for layout in _list_kb_layouts()],
                value=state.kb_layout,
                allow_blank=False,
                id="kb-layout",
            )

            yield Static("System language", classes="field-label")
            yield Select(
                [(locale, locale) for locale in _list_locales()],
                value=state.sys_lang,
                allow_blank=False,
                id="sys-lang",
            )

            yield Static("Timezone", classes="field-label")
            yield Select(
                [(tz, tz) for tz in _list_timezones()],
                value=state.timezone,
                allow_blank=False,
                id="timezone",
            )

            yield self.error_widget()
            with Horizontal(classes="button-row"):
                yield Button("Back", flat=True, id="back")
                yield Button("Continue", variant="primary", flat=True, id="continue")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "back":
            self.wizard_back()
            return

        kb_layout = self.query_one("#kb-layout", Select).value
        sys_lang = self.query_one("#sys-lang", Select).value
        timezone = self.query_one("#timezone", Select).value

        self.wizard_continue({"kb_layout": kb_layout, "sys_lang": sys_lang, "timezone": timezone})
