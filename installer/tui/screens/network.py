from textual.app import ComposeResult
from textual.containers import Horizontal, Vertical
from textual.widgets import Button, Input, RadioButton, RadioSet, Static

import network
from screens.base import WizardScreen


class NetworkScreen(WizardScreen):
    """Only reached when app.py's _skip_current_step() finds no
    existing connectivity -- ethernet users never see this screen at
    all. Manual SSID entry is the guaranteed path; the Scan button is a
    best-effort convenience on top (see network.py's own docstring on
    why its parsing can't be verified against real hardware here)."""

    def compose(self) -> ComposeResult:
        with Vertical(classes="card"):
            yield Static("Connect to Wi-Fi", classes="card-title")
            yield Static(
                "No wired connection was detected. Scan for nearby networks, "
                "or enter the network name manually.",
                classes="card-subtitle",
            )

            self._devices = network.list_station_devices()
            if not self._devices:
                yield Static("No Wi-Fi adapter detected.", classes="error-message")
            else:
                with Horizontal(classes="button-row"):
                    yield Button("Scan", flat=True, id="scan")
                yield Vertical(id="scan-results")

                yield Static("Network name (SSID)", classes="field-label")
                yield Input(placeholder="Network name", id="ssid")

                yield Static("Passphrase", classes="field-label")
                yield Input(password=True, id="passphrase")

            yield self.error_widget()
            with Horizontal(classes="button-row"):
                yield Button("Back", flat=True, id="back")
                yield Button("Skip", flat=True, id="skip")
                if self._devices:
                    yield Button("Connect", variant="primary", flat=True, id="connect")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "back":
            self.wizard_back()
            return
        if event.button.id == "skip":
            self.wizard_continue({})
            return
        if event.button.id == "scan":
            self._run_scan()
            return
        if event.button.id == "connect":
            self._attempt_connect()

    def _run_scan(self) -> None:
        results_container = self.query_one("#scan-results", Vertical)
        results_container.remove_children()

        device = self._devices[0]
        networks = network.scan_networks(device)
        if not networks:
            self.show_error("No networks found. Enter the network name manually below.")
            return

        radio_set = RadioSet(id="network-choice")
        results_container.mount(radio_set)
        for net in networks:
            radio_set.mount(RadioButton(f"{net.ssid}  ({net.security}, {net.signal})"))
        self._scanned_networks = networks

    def on_radio_set_changed(self, event: RadioSet.Changed) -> None:
        if event.radio_set.id != "network-choice":
            return
        index = event.radio_set.pressed_index
        if index is None or not (0 <= index < len(getattr(self, "_scanned_networks", []))):
            return
        self.query_one("#ssid", Input).value = self._scanned_networks[index].ssid

    def _attempt_connect(self) -> None:
        ssid = self.query_one("#ssid", Input).value.strip()
        if not ssid:
            self.show_error("Enter a network name.")
            return
        passphrase = self.query_one("#passphrase", Input).value

        success, message = network.connect(self._devices[0], ssid, passphrase)
        if not success:
            self.show_error(message or "Connection failed.")
            return
        self.wizard_continue({})
