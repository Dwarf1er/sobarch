from textual.app import ComposeResult
from textual.containers import Horizontal, Vertical
from textual.widgets import Button, Input, Static

from screens.base import WizardScreen
from validators import EMAIL_RE


class GitScreen(WizardScreen):
    def compose(self) -> ComposeResult:
        state = self.sobarch_app.state
        with Vertical(classes="card"):
            yield Static("Git identity", classes="card-title")
            yield Static(
                "Optional: sets user.name/user.email in the new account's "
                "global git config. An ed25519 SSH key is generated on first "
                "boot either way, ready to add to your git host. Leave both "
                "fields blank to skip the git config.",
                classes="card-subtitle",
            )

            yield Static("Name", classes="field-label")
            yield Input(value=state.git_name, placeholder="e.g. Alice Smith", id="git-name")

            yield Static("Email", classes="field-label")
            yield Input(value=state.git_email, placeholder="e.g. alice@example.com", id="git-email")

            yield self.error_widget()
            with Horizontal(classes="button-row"):
                yield Button("Back", flat=True, id="back")
                yield Button("Continue", variant="primary", flat=True, id="continue")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "back":
            self.wizard_back()
            return

        git_name = self.query_one("#git-name", Input).value.strip()
        git_email = self.query_one("#git-email", Input).value.strip()

        if not git_name and not git_email:
            self.wizard_continue({"git_name": "", "git_email": ""})
            return

        if not git_name or not git_email:
            self.show_error("Provide both name and email, or leave both blank to skip.")
            return
        if not EMAIL_RE.match(git_email):
            self.show_error("Email doesn't look valid.")
            return

        self.wizard_continue({"git_name": git_name, "git_email": git_email})
