from textual import work
from textual.app import ComposeResult
from textual.widgets import Input, OptionList, Static
from textual.widgets.option_list import Option

import network
from sections.base import Section
from widgets import RadioList, Row


class NetworkSection(Section):
    """Only offered when there is no connectivity at startup, so
    ethernet users never see it. Manual SSID entry is the guaranteed
    path; Scan is a best-effort convenience on top (see network.py on
    why its parsing can't be verified against real hardware here)."""

    title = "Network"

    def __init__(self, **kwargs) -> None:
        super().__init__(**kwargs)
        self._devices = network.list_station_devices()
        self._scanned: list[network.NetworkInfo] = []
        self.connected = False

    def compose(self) -> ComposeResult:
        if not self._devices:
            yield Static("No Wi-Fi adapter detected.", classes="error")
            return
        yield Static(
            "No wired connection was detected. Scan for nearby networks or enter the name manually.",
            classes="note",
        )
        yield OptionList(Option("Scan for networks", id="scan"), Option("Connect", id="connect"), id="net-actions")
        yield Static("", id="net-result", classes="note")
        yield Row("SSID", Input(placeholder="Network name", compact=True, id="ssid"))
        yield Row("Passphrase", Input(password=True, compact=True, id="passphrase"))

    def neutral(self) -> bool:
        return not self.connected

    def on_option_list_option_selected(self, event: OptionList.OptionSelected) -> None:
        event.stop()
        if event.option.id == "scan":
            self._scan()
        elif event.option.id == "connect":
            self._connect()

    def _say(self, text: str) -> None:
        self.query_one("#net-result", Static).update(text)

    @work(thread=True, exclusive=True)
    def _scan(self) -> None:
        self.app.call_from_thread(self._say, "Scanning...")
        networks = network.scan_networks(self._devices[0])
        self.app.call_from_thread(self._show_scan, networks)

    async def _show_scan(self, networks: list[network.NetworkInfo]) -> None:
        for old in self.query("#network-choice"):
            await old.remove()
        self._scanned = networks
        if not networks:
            self._say("No networks found. Enter the name manually below.")
            return
        self._say(f"{len(networks)} networks found. Enter picks one.")
        radio = RadioList([f"{n.ssid}  ({n.security}, {n.signal})" for n in networks], id="network-choice")
        await self.mount(radio, after=self.query_one("#net-result"))

    def on_radio_list_chosen(self, event: RadioList.Chosen) -> None:
        event.stop()
        self.query_one("#ssid", Input).value = self._scanned[event.index].ssid

    @work(thread=True, exclusive=True)
    def _connect(self) -> None:
        ssid = self.app.call_from_thread(lambda: self.query_one("#ssid", Input).value.strip())
        if not ssid:
            self.app.call_from_thread(self._say, "Enter a network name.")
            return
        passphrase = self.app.call_from_thread(lambda: self.query_one("#passphrase", Input).value)
        self.app.call_from_thread(self._say, f"Connecting to {ssid}...")
        success, message = network.connect(self._devices[0], ssid, passphrase)
        self.connected = success
        self.app.call_from_thread(self._say, f"Connected to {ssid}." if success else (message or "Connection failed."))
        self.app.call_from_thread(self.app.screen.refresh_marks)
