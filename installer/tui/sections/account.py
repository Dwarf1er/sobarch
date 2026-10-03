from textual.app import ComposeResult
from textual.widgets import Input

from sections.base import Section
from validators import HOSTNAME_RE, USERNAME_RE
from widgets import Row


class AccountSection(Section):
    title = "Account"
    required = True

    def compose(self) -> ComposeResult:
        state = self.sobarch_app.state
        yield Row("Hostname", Input(value=state.hostname, placeholder="e.g. workstation", compact=True, id="hostname"))
        yield Row("Username", Input(value=state.username, placeholder="e.g. alice", compact=True, id="username"))
        yield Row("Password", Input(password=True, compact=True, id="password"))
        yield Row("Confirm", Input(password=True, compact=True, id="password-confirm"))

    def _value(self, widget_id: str) -> str:
        return self.query_one(f"#{widget_id}", Input).value

    def validate(self) -> str | None:
        if not HOSTNAME_RE.match(self._value("hostname").strip()):
            return "Hostname must be lowercase alphanumeric, hyphens allowed in the middle."
        if not USERNAME_RE.match(self._value("username").strip()):
            return "Username must start with a lowercase letter or underscore."
        if not self._value("password"):
            return "Password cannot be empty."
        if self._value("password") != self._value("password-confirm"):
            return "Passwords do not match."
        return None

    def collect(self) -> None:
        state = self.sobarch_app.state
        state.hostname = self._value("hostname").strip()
        state.username = self._value("username").strip()
        matching = self._value("password") == self._value("password-confirm")
        state.password = self._value("password") if matching else ""
