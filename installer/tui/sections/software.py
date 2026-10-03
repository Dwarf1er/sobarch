"""Two selection levels: install everything, or choose specific
profiles, each either taken whole or expanded to hand-pick packages.
There is deliberately no separate flat-package mode: picking inside a
profile already reaches past its boundary."""

from rich.text import Text
from textual.app import ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal
from textual.widgets import ContentSwitcher, OptionList, SelectionList
from textual.widgets.option_list import Option

from profiles_data import PROFILES
from sections.base import Section
from widgets import Toggle


class SoftwareSection(Section):
    title = "Software"

    BINDINGS = [Binding("a", "toggle_all", "All/none in profile")]

    def compose(self) -> ComposeResult:
        state = self.sobarch_app.state
        yield Toggle("Install everything (every profile, in full)", state.install_everything, id="install-everything")
        with Horizontal(id="profiles"):
            yield OptionList(*[Option(self._prompt(p.name, 0, len(p.packages)), id=p.slug) for p in PROFILES], id="profile-nav")
            with ContentSwitcher(initial=f"pkgs-{PROFILES[0].slug}", id="profile-detail"):
                for profile in PROFILES:
                    chosen = set(state.profile_packages.get(profile.name, []))
                    yield SelectionList(
                        *[
                            (f"{pkg.name} (AUR)" if pkg.aur else pkg.name, pkg.name, pkg.name in chosen)
                            for pkg in profile.packages
                        ],
                        id=f"pkgs-{profile.slug}",
                    )

    @staticmethod
    def _prompt(name: str, picked: int, total: int) -> Text:
        mark = "[x]" if picked == total else "[~]" if picked else "[ ]"
        return Text.assemble((mark + " ", "dim"), f"{name:<20}", (f"{picked}/{total}", "dim"))

    def on_mount(self) -> None:
        self.query_one("#profile-nav", OptionList).highlighted = 0
        for profile in PROFILES:
            self._refresh_profile(profile.slug)
        self._sync_enabled()

    def _list(self, slug: str) -> SelectionList:
        return self.query_one(f"#pkgs-{slug}", SelectionList)

    def _refresh_profile(self, slug: str) -> None:
        profile = next(p for p in PROFILES if p.slug == slug)
        nav = self.query_one("#profile-nav", OptionList)
        picked = len(self._list(slug).selected)
        nav.replace_option_prompt(slug, self._prompt(profile.name, picked, len(profile.packages)))

    def _sync_enabled(self) -> None:
        everything = self.query_one("#install-everything", Toggle).value
        self.query_one("#profiles").disabled = everything

    def on_toggle_changed(self, event: Toggle.Changed) -> None:
        self._sync_enabled()

    def on_option_list_option_highlighted(self, event: OptionList.OptionHighlighted) -> None:
        if event.option_list.id == "profile-nav" and event.option.id:
            self.query_one("#profile-detail", ContentSwitcher).current = f"pkgs-{event.option.id}"

    def on_option_list_option_selected(self, event: OptionList.OptionSelected) -> None:
        # Enter on a profile moves into its package list.
        if event.option_list.id == "profile-nav" and event.option.id:
            event.stop()
            self._list(event.option.id).focus()

    def on_selection_list_selected_changed(self, event: SelectionList.SelectedChanged) -> None:
        if event.selection_list.id:
            self._refresh_profile(event.selection_list.id.removeprefix("pkgs-"))

    def action_toggle_all(self) -> None:
        nav = self.query_one("#profile-nav", OptionList)
        if nav.highlighted is None:
            return
        packages = self._list(PROFILES[nav.highlighted].slug)
        if len(packages.selected) == len(PROFILES[nav.highlighted].packages):
            packages.deselect_all()
        else:
            packages.select_all()

    def collect(self) -> None:
        state = self.sobarch_app.state
        state.install_everything = self.query_one("#install-everything", Toggle).value
        state.profile_packages = {}
        if state.install_everything:
            return
        for profile in PROFILES:
            selected = list(self._list(profile.slug).selected)
            if selected:
                state.profile_packages[profile.name] = selected
