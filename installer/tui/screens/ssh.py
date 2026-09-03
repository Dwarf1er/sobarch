from textual.app import ComposeResult
from textual.containers import Horizontal, Vertical
from textual.widgets import Button, Static, Switch

from screens.base import WizardScreen


class SshScreen(WizardScreen):
    def compose(self) -> ComposeResult:
        state = self.sobarch_app.state
        with Vertical(classes="card"):
            yield Static("Remote access", classes="card-title")
            yield Static(
                "SSH is disabled by default. Enabling it "
                "installs openssh, opens the matching firewall exception, "
                "and disables root login over SSH via a sshd_config.d "
                "drop-in; root login is locked either way.",
                classes="card-subtitle",
            )

            with Horizontal():
                yield Switch(value=state.ssh_enabled, id="ssh-toggle")
                yield Static(" Enable SSH", classes="field-label")

            yield self.error_widget()
            with Horizontal(classes="button-row"):
                yield Button("Back", flat=True, id="back")
                yield Button("Continue", variant="primary", flat=True, id="continue")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "back":
            self.wizard_back()
            return

        ssh_enabled = self.query_one("#ssh-toggle", Switch).value
        self.wizard_continue({"ssh_enabled": ssh_enabled})
