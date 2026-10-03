import os
import subprocess

from rich.text import Text
from textual import work
from textual.app import ComposeResult
from textual.widgets import OptionList, RichLog, Static
from textual.widgets.option_list import Option

from config_gen import (
    ConfigGenError,
    generate_configs,
    write_configs,
    write_firstboot_package_lists,
    write_git_config,
    write_profile_selection,
    write_security_flags,
)
from install_runner import InstallError, run_install
from profiles_data import resolve_selection
from sections.base import Section

_SPINNER = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"


def _profiles_summary(state) -> str:
    if state.install_everything:
        return "all profiles (every package)"
    selection = resolve_selection(state.install_everything, state.profile_packages)
    if not selection:
        return "none"
    return ", ".join(f"{name} ({len(packages)} pkgs)" for name, packages in selection.items())


class InstallSection(Section):
    title = "Install"

    def __init__(self, **kwargs) -> None:
        super().__init__(**kwargs)
        self._confirming = False
        self.running = False
        self._spin = 0

    def compose(self) -> ComposeResult:
        yield Static("", id="summary")
        yield OptionList(id="install-actions")
        yield Static("", id="install-note", classes="note")
        yield RichLog(id="log", max_lines=500, wrap=True)

    def on_mount(self) -> None:
        self.query_one("#log").display = False
        self._set_actions()

    def _can_install(self) -> bool:
        return not self.sobarch_app.dry_run and os.geteuid() == 0

    def _set_actions(self, *, confirm: bool = False) -> None:
        actions = self.query_one("#install-actions", OptionList)
        actions.clear_options()
        options = [Option("Save configuration", id="save")]
        if self._can_install():
            if confirm:
                disk = self.sobarch_app.state.disk_device
                options.append(Option(Text(f"Confirm: install now and modify {disk}", style="bold red"), id="install"))
            else:
                options.append(Option("Install now", id="install"))
        actions.add_options(options)
        actions.highlighted = len(options) - 1 if confirm else 0

    def on_show(self) -> None:
        if self.running:
            return
        state = self.sobarch_app.state
        target = state.disk_device or "(none)"
        if state.free_space_install:
            target += "  (dual-boot, free space only)"
        lines = [
            ("Disk", target),
            ("Encryption", "LUKS (root partition)" if state.disk_encryption_enabled else "disabled"),
            ("Hostname", state.hostname),
            ("Username", state.username),
            ("Keyboard", state.kb_layout),
            ("Language", state.sys_lang),
            ("Timezone", state.timezone),
            ("Mirrors", state.mirror_region or "automatic"),
            ("Rescue ISO", "yes" if state.rescue_media else "no"),
            ("SSH", "enabled" if state.ssh_enabled else "disabled"),
            ("Git config", f"{state.git_name} <{state.git_email}>" if state.git_name else "skipped"),
            ("Software", _profiles_summary(state)),
        ]
        summary = Text()
        for key, value in lines:
            summary.append(f"{key:<12}", style="dim")
            summary.append(f"{value}\n")
        self.query_one("#summary", Static).update(summary)

        note = self.query_one("#install-note", Static)
        if self.sobarch_app.dry_run:
            note.update("--dry-run: install is disabled, only saving the generated config is available.")
        elif not self._can_install():
            note.update("Root privileges are required to install; only saving the generated config is available.")
        else:
            note.update("")
        self._confirming = False
        self._set_actions()

    def on_option_list_option_selected(self, event: OptionList.OptionSelected) -> None:
        event.stop()
        screen = self.sobarch_app.screen
        action = event.option.id

        if action in ("save", "install"):
            problems = screen.incomplete_steps()
            if problems:
                self.query_one("#install-note", Static).update(Text("Incomplete: " + ", ".join(problems), style="red"))
                return

        if action == "save":
            self._save_configuration()
        elif action == "install":
            if not self._confirming:
                self._confirming = True
                self._set_actions(confirm=True)
                return
            self._start_install()
        elif action == "reboot":
            subprocess.run(["systemctl", "reboot"])
        elif action == "quit":
            self.sobarch_app.exit()

    def on_key(self, event) -> None:
        if event.key == "escape" and self._confirming:
            event.stop()
            self._confirming = False
            self._set_actions()

    def _save_configuration(self) -> None:
        app = self.sobarch_app
        out_dir = app.output_dir
        note = self.query_one("#install-note", Static)
        try:
            generated = generate_configs(app.state, app.get_hardware())
            paths = [
                *write_configs(generated, out_dir),
                write_profile_selection(app.state, out_dir),
                *write_firstboot_package_lists(app.state, out_dir),
                write_security_flags(app.state, out_dir),
                write_git_config(app.state, out_dir),
            ]
        except ConfigGenError as error:
            note.update(Text(str(error), style="red"))
            return
        note.update("\n".join(f"Saved: {path}" for path in paths))

    def _start_install(self) -> None:
        self.running = True
        self.sobarch_app.screen.set_locked(True)
        self.query_one("#summary").display = False
        self.query_one("#install-actions").display = False
        self.query_one("#install-note").display = False
        log = self.query_one("#log", RichLog)
        log.display = True
        self._spinner = self.set_interval(0.1, self._tick)
        self._run()

    def _tick(self) -> None:
        self._spin = (self._spin + 1) % len(_SPINNER)
        self.border_title = f"Installing {_SPINNER[self._spin]}"

    @work(thread=True, exclusive=True)
    def _run(self) -> None:
        app = self.sobarch_app
        try:
            generated = generate_configs(app.state, app.get_hardware())
        except ConfigGenError as error:
            self._finish(False, str(error), None)
            return

        try:
            run_install(app.state, app.get_hardware(), generated, app.output_dir, on_output=self._on_output)
        except InstallError as error:
            self._finish(False, str(error), error.log_path)
            return
        except subprocess.CalledProcessError as error:
            self._finish(False, str(error), app.output_dir / "install.log")
            return

        self._finish(True, "", None)

    def _on_output(self, line: str) -> None:
        self.app.call_from_thread(self.query_one("#log", RichLog).write, line)

    def _finish(self, ok: bool, message: str, log_path) -> None:
        def update() -> None:
            self._spinner.stop()
            self.border_title = "Installation complete" if ok else "Installation failed"
            if not ok:
                note = f"\nFull log: {log_path}" if log_path else ""
                self.query_one("#log", RichLog).write(Text(f"ERROR: {message}{note}", style="bold red"))
            actions = self.query_one("#install-actions", OptionList)
            actions.clear_options()
            if ok:
                actions.add_option(Option("Reboot now", id="reboot"))
            actions.add_option(Option("Quit", id="quit"))
            actions.display = True
            actions.highlighted = 0
            actions.focus()

        self.app.call_from_thread(update)
