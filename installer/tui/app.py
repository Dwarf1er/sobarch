"""The install wizard's App: owns the shared WizardState, steps
screens forward/backward by index (not by the screen stack, see
screens/base.py), and lazily detects hardware once it's actually
needed."""

import os
from pathlib import Path

from textual.app import App

from hardware import HardwareInfo, detect_hardware
from screens.account import AccountScreen
from screens.disk import DiskScreen
from screens.localization import LocalizationScreen
from screens.profiles import ProfilesScreen
from screens.progress import ProgressScreen
from screens.rescue import RescueScreen
from screens.review import ReviewScreen
from screens.welcome import WelcomeScreen
from state import WizardState
from theme import ONEDARK_THEME

STEPS = [
    WelcomeScreen,
    DiskScreen,
    AccountScreen,
    LocalizationScreen,
    RescueScreen,
    ProfilesScreen,
    ReviewScreen,
]


class SobarchApp(App):
    CSS_PATH = "styles.tcss"
    TITLE = "sobarch installer"

    def __init__(self, dry_run: bool = False, output_dir: Path | None = None) -> None:
        super().__init__()
        self.state = WizardState()
        self.dry_run = dry_run
        self.output_dir = output_dir or self.default_output_dir()
        self._hardware: HardwareInfo | None = None
        self._step_index = 0

    @staticmethod
    def default_output_dir() -> Path:
        if os.geteuid() == 0:
            return Path("/root/sobarch-install")
        return Path.cwd() / "sobarch-install-output"

    def on_mount(self) -> None:
        self.register_theme(ONEDARK_THEME)
        self.theme = "onedark"
        self.push_screen(STEPS[0]())

    def get_hardware(self) -> HardwareInfo:
        if self._hardware is None:
            self._hardware = detect_hardware()
        return self._hardware

    def wizard_advance(self, updates: dict) -> None:
        for key, value in updates.items():
            setattr(self.state, key, value)

        self._step_index += 1
        if self._step_index >= len(STEPS):
            self._step_index = len(STEPS) - 1
        self.switch_screen(STEPS[self._step_index]())

    def wizard_back(self) -> None:
        if self._step_index == 0:
            return
        self._step_index -= 1
        self.switch_screen(STEPS[self._step_index]())

    def begin_install(self) -> None:
        self.switch_screen(ProgressScreen())
