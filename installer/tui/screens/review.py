import os

from textual.app import ComposeResult
from textual.containers import Horizontal, Vertical
from textual.widgets import Button, Static

from config_gen import (
    ConfigGenError,
    generate_configs,
    write_configs,
    write_firstboot_package_lists,
    write_profile_selection,
    write_security_flags,
)
from profiles_data import resolve_selection
from screens.base import WizardScreen


def _profiles_summary(state) -> str:
    if state.install_everything:
        return "all profiles (every package)"
    selection = resolve_selection(state.install_everything, state.profile_packages)
    if not selection:
        return "none"
    return ", ".join(f"{name} ({len(packages)} pkgs)" for name, packages in selection.items())


class ReviewScreen(WizardScreen):
    def compose(self) -> ComposeResult:
        state = self.sobarch_app.state
        with Vertical(classes="card"):
            yield Static("Review", classes="card-title")

            summary_lines = [
                f"Disk:       {state.disk_device}",
                f"Hostname:   {state.hostname}",
                f"Username:   {state.username}",
                f"Keyboard:   {state.kb_layout}",
                f"Language:   {state.sys_lang}",
                f"Timezone:   {state.timezone}",
                f"Rescue ISO: {'yes' if state.rescue_media else 'no'}",
                f"Profiles:   {_profiles_summary(state)}",
                f"SSH:        {'enabled' if state.ssh_enabled else 'disabled'}",
            ]
            yield Static("\n".join(summary_lines), classes="card-subtitle")

            yield self.error_widget()
            yield Static("", id="status-message", classes="card-subtitle")

            with Horizontal(classes="button-row"):
                yield Button("Back", flat=True, id="back")
                yield Button("Save configuration", flat=True, id="save")
                if self._can_install():
                    yield Button("Install now", variant="primary", flat=True, id="install")

    def _can_install(self) -> bool:
        return not self.sobarch_app.dry_run and os.geteuid() == 0

    def on_mount(self) -> None:
        if self.sobarch_app.dry_run:
            self.query_one("#status-message", Static).update(
                "--dry-run: install is disabled, only saving the generated config is available."
            )
        elif not self._can_install():
            self.query_one("#status-message", Static).update(
                "Root privileges are required to install; only saving the generated config is available."
            )

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "back":
            self.wizard_back()
            return

        if event.button.id == "save":
            self._save_configuration()
            return

        if event.button.id == "install":
            self.sobarch_app.begin_install()

    def _save_configuration(self) -> None:
        state = self.sobarch_app.state
        out_dir = self.sobarch_app.output_dir
        try:
            generated = generate_configs(state, self.sobarch_app.get_hardware())
            base_path, credentials_path = write_configs(generated, out_dir)
            profiles_path = write_profile_selection(state, out_dir)
            official_path, aur_path = write_firstboot_package_lists(state, out_dir)
            ssh_path = write_security_flags(state, out_dir)
        except ConfigGenError as error:
            self.show_error(str(error))
            return

        self.clear_error()
        saved_paths = [base_path, credentials_path, profiles_path, official_path, aur_path, ssh_path]
        self.query_one("#status-message", Static).update(
            "\n".join(f"Saved: {path}" for path in saved_paths)
        )
