from textual.app import ComposeResult
from textual.widgets import Input, Static

from sections.base import Section
from validators import EMAIL_RE
from widgets import Row, Toggle

# Approximate, not live-fetched: the actual monthly ISO size drifts a
# little release to release, and this screen shouldn't gain a network
# dependency (and its failure mode) just to size a checkbox.
_RESCUE_NOTE = (
    "Rescue media stores a full Arch ISO (~1.5 GiB) on its own partition so the "
    "machine can boot a rescue environment with no USB drive around. "
    "It adds a real download during install."
)
_SSH_NOTE = (
    "SSH is off by default. Enabling it installs openssh, opens the firewall "
    "exception and disables root login over SSH. Root login is locked either way."
)
_GIT_NOTE = (
    "Optional git identity for the new account. Leave both blank to skip. "
    "An ed25519 SSH key is generated on first boot regardless."
)


class OptionsSection(Section):
    title = "Options"

    def compose(self) -> ComposeResult:
        state = self.sobarch_app.state
        yield Static("Rescue media", classes="heading")
        yield Static(_RESCUE_NOTE, classes="note")
        yield Toggle("Include rescue media", state.rescue_media, id="rescue-toggle")
        yield Static("Remote access", classes="heading")
        yield Static(_SSH_NOTE, classes="note")
        yield Toggle("Enable SSH", state.ssh_enabled, id="ssh-toggle")
        yield Static("Git identity", classes="heading")
        yield Static(_GIT_NOTE, classes="note")
        yield Row("Name", Input(value=state.git_name, placeholder="e.g. Alice Smith", compact=True, id="git-name"))
        yield Row("Email", Input(value=state.git_email, placeholder="e.g. alice@example.com", compact=True, id="git-email"))

    def on_show(self) -> None:
        rescue = self.query_one("#rescue-toggle", Toggle)
        if self.sobarch_app.state.free_space_install:
            rescue.set_value(False)
            rescue.disabled = True
            rescue.set_label("Include rescue media (unavailable for dual-boot installs)")
        else:
            rescue.disabled = False
            rescue.set_label("Include rescue media")

    def validate(self) -> str | None:
        name = self.query_one("#git-name", Input).value.strip()
        email = self.query_one("#git-email", Input).value.strip()
        if bool(name) != bool(email):
            return "Provide both git name and email, or leave both blank to skip."
        if email and not EMAIL_RE.match(email):
            return "Git email doesn't look valid."
        return None

    def collect(self) -> None:
        state = self.sobarch_app.state
        state.rescue_media = (
            False if state.free_space_install else self.query_one("#rescue-toggle", Toggle).value
        )
        state.ssh_enabled = self.query_one("#ssh-toggle", Toggle).value
        state.git_name = self.query_one("#git-name", Input).value.strip()
        state.git_email = self.query_one("#git-email", Input).value.strip()
