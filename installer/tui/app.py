"""The installer App: owns the shared WizardState, detects hardware
lazily once it's actually needed, and shows the single MainScreen."""

import os
from pathlib import Path

from textual.app import App

from hardware import HardwareInfo, detect_hardware
from main_screen import MainScreen
from state import WizardState
from theme import ONEDARK_THEME


class SobarchApp(App):
    CSS_PATH = "styles.tcss"
    TITLE = "sobarch installer"
    ENABLE_COMMAND_PALETTE = False

    def __init__(self, dry_run: bool = False, output_dir: Path | None = None) -> None:
        super().__init__()
        self.state = WizardState()
        self.dry_run = dry_run
        self.output_dir = output_dir or self.default_output_dir()
        self._hardware: HardwareInfo | None = None

    @staticmethod
    def default_output_dir() -> Path:
        if os.geteuid() == 0:
            return Path("/root/sobarch-install")
        return Path.cwd() / "sobarch-install-output"

    def on_mount(self) -> None:
        self.register_theme(ONEDARK_THEME)
        self.theme = "onedark"
        self.push_screen(MainScreen())

    def get_hardware(self) -> HardwareInfo:
        if self._hardware is None:
            self._hardware = detect_hardware()
        return self._hardware
