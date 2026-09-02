"""Implements two selection levels: install everything, or choose
specific profiles, each either taken as a whole or expanded to
hand-pick individual packages. There is deliberately no third,
separate "Advanced" flat-package mode: expand-to-hand-pick already
lets anyone reach past a profile's boundary without leaving the
profile system entirely."""

from textual.app import ComposeResult
from textual.containers import Horizontal, Vertical
from textual.widgets import Button, Checkbox, Collapsible, SelectionList, Static, Switch

from profiles_data import PROFILES
from screens.base import WizardScreen


class ProfilesScreen(WizardScreen):
    def compose(self) -> ComposeResult:
        state = self.sobarch_app.state
        with Vertical(classes="card"):
            yield Static("Optional software profiles", classes="card-title")
            yield Static(
                "Optional, applied after first boot. Leave everything "
                "unchecked to keep the base install minimal.",
                classes="card-subtitle",
            )

            with Horizontal(classes="install-everything-row"):
                yield Switch(value=state.install_everything, id="install-everything")
                yield Static(" Install everything (every profile, in full)", classes="field-label")

            with Vertical(id="profile-list"):
                for profile in PROFILES:
                    selected_packages = set(state.profile_packages.get(profile.name, []))
                    all_names = {pkg.name for pkg in profile.packages}
                    with Collapsible(title=profile.name, collapsed=True, id=f"collapsible-{profile.slug}"):
                        yield Checkbox(
                            "Select entire profile",
                            value=bool(selected_packages) and selected_packages == all_names,
                            id=f"toggle-{profile.slug}",
                        )
                        yield SelectionList(
                            *[
                                (
                                    f"{pkg.name} (AUR)" if pkg.aur else pkg.name,
                                    pkg.name,
                                    pkg.name in selected_packages,
                                )
                                for pkg in profile.packages
                            ],
                            id=f"pkgs-{profile.slug}",
                        )

            yield self.error_widget()
            with Horizontal(classes="button-row"):
                yield Button("Back", flat=True, id="back")
                yield Button("Continue", variant="primary", flat=True, id="continue")

    def on_mount(self) -> None:
        self._set_profile_list_visible(not self.sobarch_app.state.install_everything)

    def on_switch_changed(self, event: Switch.Changed) -> None:
        if event.switch.id == "install-everything":
            self._set_profile_list_visible(not event.value)

    def _set_profile_list_visible(self, visible: bool) -> None:
        self.query_one("#profile-list", Vertical).display = visible

    def on_checkbox_changed(self, event: Checkbox.Changed) -> None:
        if event.checkbox.id is None or not event.checkbox.id.startswith("toggle-"):
            return
        slug = event.checkbox.id.removeprefix("toggle-")
        packages_list = self.query_one(f"#pkgs-{slug}", SelectionList)
        if event.value:
            packages_list.select_all()
        else:
            packages_list.deselect_all()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "back":
            self.wizard_back()
            return

        install_everything = self.query_one("#install-everything", Switch).value

        profile_packages: dict[str, list[str]] = {}
        if not install_everything:
            for profile in PROFILES:
                selected = list(self.query_one(f"#pkgs-{profile.slug}", SelectionList).selected)
                if selected:
                    profile_packages[profile.name] = selected

        self.wizard_continue(
            {"install_everything": install_everything, "profile_packages": profile_packages}
        )
