import os
import re
import subprocess
from pathlib import PurePosixPath

from rich.text import Text
from textual import work
from textual.app import ComposeResult
from textual.widgets import Input, OptionList, RichLog, Static
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
from disks import list_disks
from install_runner import InstallError, run_install
from profiles_data import resolve_selection
from sections.base import Section

_SPINNER = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"

# Anything left after Text.from_ansi has taken the colour codes it
# understands: other escape sequences (cursor movement, erase) and bare
# control characters, which a terminal would act on instead of print.
_ESCAPE_RE = re.compile(r"\x1b(?:\[[0-?]*[ -/]*[@-~]|[@-Z\\-_]|\][^\x07]*\x07)")
_CONTROL_RE = re.compile(r"[\x00-\x08\x0b-\x1f\x7f]")


def _clean_line(line: str) -> Text:
    """Installer output is written for a real terminal: ANSI colours,
    carriage-return progress redraws, tabs. Rendered raw, those corrupt
    the pane, so keep only what a redraw would finally leave visible."""
    parts = [part for part in line.split("\r") if part.strip()]
    line = parts[-1] if parts else ""
    line = _ESCAPE_RE.sub(lambda m: m.group(0) if m.group(0).endswith("m") else "", line)
    text = Text.from_ansi(line.expandtabs(4))
    text.plain = _CONTROL_RE.sub("", text.plain) if _CONTROL_RE.search(text.plain) else text.plain
    return text


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
        yield Input(placeholder="type the disk name to confirm", compact=True, id="install-confirm")
        yield RichLog(id="log", max_lines=500, wrap=True, min_width=1, markup=False)

    def on_mount(self) -> None:
        self.query_one("#log").display = False
        self.query_one("#install-confirm").display = False
        self._set_actions()

    def _can_install(self) -> bool:
        return not self.sobarch_app.dry_run and os.geteuid() == 0

    def _set_actions(self) -> None:
        actions = self.query_one("#install-actions", OptionList)
        actions.clear_options()
        options = [Option("Save configuration", id="save")]
        if self._can_install():
            options.append(Option("Install now", id="install"))
        actions.add_options(options)
        actions.highlighted = 0

    def _confirm_name(self) -> str:
        return PurePosixPath(self.sobarch_app.state.disk_device or "").name

    def _begin_confirm(self) -> None:
        state = self.sobarch_app.state
        disk = state.disk_device
        existing = next((d.partitions for d in list_disks() if d.path == disk), ())
        warning = Text()
        if state.free_space_install:
            warning.append(f"New partitions will be created in the free space on {disk}.\n", style="bold red")
            warning.append("Existing partitions are left untouched.\n")
        else:
            warning.append(f"ALL DATA ON {disk} WILL BE ERASED.\n", style="bold red")
            if existing:
                warning.append("Partitions that will be destroyed:\n")
                for line in existing:
                    warning.append(f"  {line}\n")
        warning.append(f"Type {self._confirm_name()!r} and press Enter to install, Esc to cancel.")
        self.query_one("#install-note", Static).update(warning)
        confirm = self.query_one("#install-confirm", Input)
        confirm.value = ""
        confirm.display = True
        confirm.focus()

    def _cancel_confirm(self) -> None:
        self._confirming = False
        confirm = self.query_one("#install-confirm", Input)
        confirm.display = False
        confirm.value = ""
        self.query_one("#install-note", Static).update("")
        self.query_one("#install-actions", OptionList).focus()

    def on_input_submitted(self, event: Input.Submitted) -> None:
        if event.input.id != "install-confirm":
            return
        event.stop()
        if not self._confirming:
            return
        if event.value.strip() != self._confirm_name():
            self.query_one("#install-note", Static).update(
                Text(f"Doesn't match. Type {self._confirm_name()!r} exactly, or press Esc to cancel.", style="red")
            )
            return
        self._confirming = False
        event.input.display = False
        self._start_install()

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
            ("Mirrors", ", ".join(state.mirror_regions) or "automatic"),
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
        self._cancel_confirm()

        note = self.query_one("#install-note", Static)
        if self.sobarch_app.dry_run:
            note.update("--dry-run: install is disabled, only saving the generated config is available.")
        elif not self._can_install():
            note.update("Root privileges are required to install; only saving the generated config is available.")
        else:
            note.update("")
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
            self._confirming = True
            self._begin_confirm()
        elif action == "reboot":
            subprocess.run(["systemctl", "reboot"])
        elif action == "quit":
            self.sobarch_app.exit()

    def on_key(self, event) -> None:
        if event.key == "escape" and self._confirming:
            event.stop()
            self._cancel_confirm()

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
        self.app.call_from_thread(self.query_one("#log", RichLog).write, _clean_line(line))

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
