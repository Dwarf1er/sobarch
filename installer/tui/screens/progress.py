import subprocess

from textual import work
from textual.app import ComposeResult
from textual.containers import Horizontal, Vertical
from textual.widgets import Button, LoadingIndicator, RichLog, Static

from config_gen import ConfigGenError, generate_configs
from install_runner import InstallError, run_install
from screens.base import WizardScreen


class ProgressScreen(WizardScreen):
    def compose(self) -> ComposeResult:
        with Vertical(classes="card"):
            yield Static("Installing sobarch", classes="card-title", id="progress-title")
            yield LoadingIndicator(id="spinner")
            yield RichLog(id="log", max_lines=200)
            with Horizontal(classes="button-row", id="button-row"):
                yield Button("Quit", flat=True, id="quit")

    def on_mount(self) -> None:
        self._run()

    @work(thread=True, exclusive=True)
    def _run(self) -> None:
        app = self.sobarch_app
        try:
            generated = generate_configs(app.state, app.get_hardware())
        except ConfigGenError as error:
            self._on_failed(str(error), None)
            return

        try:
            run_install(
                app.state,
                app.get_hardware(),
                generated,
                app.output_dir,
                on_output=self._on_output,
            )
        except InstallError as error:
            self._on_failed(str(error), error.log_path)
            return
        except subprocess.CalledProcessError as error:
            self._on_failed(str(error), app.output_dir / "install.log")
            return

        self._on_success()

    def _on_output(self, line: str) -> None:
        self.app.call_from_thread(self.query_one("#log", RichLog).write, line)

    def _on_failed(self, message: str, log_path) -> None:
        def update() -> None:
            self.query_one("#spinner", LoadingIndicator).remove()
            self.query_one("#progress-title", Static).update("Installation failed")
            log_note = f"\nFull log: {log_path}" if log_path else ""
            self.query_one("#log", RichLog).write(f"ERROR: {message}{log_note}")

        self.app.call_from_thread(update)

    def _on_success(self) -> None:
        def update() -> None:
            self.query_one("#spinner", LoadingIndicator).remove()
            self.query_one("#progress-title", Static).update("Installation complete")
            button_row = self.query_one("#button-row", Horizontal)
            button_row.mount(Button("Reboot now", variant="primary", flat=True, id="reboot"))

        self.app.call_from_thread(update)

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "quit":
            self.sobarch_app.exit()
        elif event.button.id == "reboot":
            subprocess.run(["systemctl", "reboot"])
