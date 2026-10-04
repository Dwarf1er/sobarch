from textual import work
from textual.app import ComposeResult
from textual.widgets import Select, SelectionList, Static

from sections.base import Section
from widgets import Row, TypeAheadSelectionList

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


def _list_mirror_regions() -> list[str]:
    """Queries archlinux.org's own mirror-status data (falling back to
    the live system's local mirrorlist if offline), the same source
    archinstall itself uses to validate mirror_regions: a network call,
    so only ever run off the UI thread, and an empty/failed result just
    means the Select offers Automatic only."""
    try:
        from archinstall.lib.mirror.mirror_handler import MirrorListHandler

        regions = MirrorListHandler().get_mirror_regions()
        return sorted({region.name for region in regions if region.name})
    except Exception:
        return []


class LocaleSection(Section):
    title = "Locale"
    _mirrors_loaded = False

    def compose(self) -> ComposeResult:
        state = self.sobarch_app.state
        yield Row(
            "Keyboard",
            Select([(v, v) for v in _list_kb_layouts()], value=state.kb_layout, allow_blank=False, compact=True, id="kb-layout"),
        )
        yield Row(
            "Language",
            Select([(v, v) for v in _list_locales()], value=state.sys_lang, allow_blank=False, compact=True, id="sys-lang"),
        )
        yield Row(
            "Timezone",
            Select([(v, v) for v in _list_timezones()], value=state.timezone, allow_blank=False, compact=True, id="timezone"),
        )
        yield Static("Mirror regions", classes="heading", id="mirror-heading")
        yield Static(
            "Type to jump to a region, space toggles it. Pick none for automatic "
            "(recommended): the live ISO's speed-ranked mirrors are kept.",
            classes="note",
            id="mirror-note",
        )
        yield TypeAheadSelectionList(id="mirror-list")

    def on_mount(self) -> None:
        # collect() must not read the list before the (network) region
        # fetch has filled it, or it would wipe the state's selection.
        self.query_one("#mirror-heading", Static).update("Mirror regions (loading...)")
        self._load_mirror_regions()

    @work(thread=True)
    def _load_mirror_regions(self) -> None:
        regions = _list_mirror_regions()
        self.app.call_from_thread(self._apply_mirror_regions, regions)

    def _apply_mirror_regions(self, regions: list[str]) -> None:
        chosen = set(self.sobarch_app.state.mirror_regions)
        # A selected region the fetch no longer offers is dropped rather
        # than kept invisibly in the state.
        self.query_one("#mirror-list", SelectionList).add_options(
            [(region, region, region in chosen) for region in regions]
        )
        self._mirrors_loaded = True
        self._update_mirror_heading()
        self.screen.refresh_marks()

    def _update_mirror_heading(self) -> None:
        count = len(self.query_one("#mirror-list", SelectionList).selected)
        text = "Mirror regions (automatic)" if not count else f"Mirror regions ({count} selected)"
        self.query_one("#mirror-heading", Static).update(text)

    def on_selection_list_selected_changed(self, event: SelectionList.SelectedChanged) -> None:
        self._update_mirror_heading()

    def collect(self) -> None:
        state = self.sobarch_app.state
        state.kb_layout = self.query_one("#kb-layout", Select).value
        state.sys_lang = self.query_one("#sys-lang", Select).value
        state.timezone = self.query_one("#timezone", Select).value
        if self._mirrors_loaded:
            state.mirror_regions = list(self.query_one("#mirror-list", SelectionList).selected)
