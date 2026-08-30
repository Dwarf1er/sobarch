import re

from textual.app import ComposeResult
from textual.containers import Horizontal, Vertical
from textual.widgets import Button, Input, Static

from screens.base import WizardScreen

_HOSTNAME_RE = re.compile(r"^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$")
_USERNAME_RE = re.compile(r"^[a-z_][a-z0-9_-]*$")


class AccountScreen(WizardScreen):
    def compose(self) -> ComposeResult:
        state = self.sobarch_app.state
        with Vertical(classes="card"):
            yield Static("Hostname and user account", classes="card-title")

            yield Static("Hostname", classes="field-label")
            yield Input(value=state.hostname, placeholder="e.g. workstation", id="hostname")

            yield Static("Username", classes="field-label")
            yield Input(value=state.username, placeholder="e.g. alice", id="username")

            yield Static("Password", classes="field-label")
            yield Input(password=True, id="password")

            yield Static("Confirm password", classes="field-label")
            yield Input(password=True, id="password-confirm")

            yield self.error_widget()
            with Horizontal(classes="button-row"):
                yield Button("Back", flat=True, id="back")
                yield Button("Continue", variant="primary", flat=True, id="continue")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "back":
            self.wizard_back()
            return

        hostname = self.query_one("#hostname", Input).value.strip()
        username = self.query_one("#username", Input).value.strip()
        password = self.query_one("#password", Input).value
        password_confirm = self.query_one("#password-confirm", Input).value

        if not _HOSTNAME_RE.match(hostname):
            self.show_error("Hostname must be lowercase alphanumeric, hyphens allowed in the middle.")
            return
        if not _USERNAME_RE.match(username):
            self.show_error("Username must start with a lowercase letter or underscore.")
            return
        if not password:
            self.show_error("Password cannot be empty.")
            return
        if password != password_confirm:
            self.show_error("Passwords do not match.")
            return

        self.wizard_continue({"hostname": hostname, "username": username, "password": password})
