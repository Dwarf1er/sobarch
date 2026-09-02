"""Runs the real install: archinstall itself, then the post-archinstall,
pre-reboot arch-chroot step (nvidia-setup.sh, snapper-setup.sh,
rescue-iso-setup.sh, in that order) against the still-mounted target.
Only meaningfully testable on a real Arch ISO with a real disk; kept in
its own module, independent of the Screen that drives it, so at least
its config-generation half stays covered by the same tests as the rest
of config_gen.py."""

import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

from config_gen import GeneratedConfig, partition_device_path, write_configs
from hardware import HardwareInfo
from state import WizardState

MOUNTPOINT = Path("/mnt")
ARCHINSTALL_DIR = Path(__file__).resolve().parent.parent / "archinstall"
CHROOT_SETUP_SCRIPTS = ["nvidia-setup.sh", "snapper-setup.sh", "rescue-iso-setup.sh"]
CHROOT_SETUP_DIR_IN_TARGET = Path("/root/sobarch-setup")

OutputCallback = Callable[[str], None]


class InstallError(Exception):
    def __init__(self, message: str, log_path: Path):
        super().__init__(message)
        self.log_path = log_path


@dataclass
class InstallPaths:
    base_config: Path
    credentials: Path
    log: Path


def _run_logged(cmd: list[str], log_file, on_output: OutputCallback, **kwargs) -> int:
    process = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
        **kwargs,
    )
    assert process.stdout is not None
    for line in process.stdout:
        log_file.write(line)
        log_file.flush()
        on_output(line.rstrip("\n"))
    return process.wait()


def run_install(
    state: WizardState,
    hardware: HardwareInfo,
    generated: GeneratedConfig,
    output_dir: Path,
    on_output: OutputCallback,
) -> None:
    base_path, credentials_path = write_configs(generated, output_dir)
    log_path = output_dir / "install.log"

    with log_path.open("a") as log_file:
        log_file.write(f"\n----- archinstall run: {state.hostname} -----\n")

        on_output(f"Running archinstall (log: {log_path})...")
        returncode = _run_logged(
            [
                "archinstall",
                "--config", str(base_path),
                "--creds", str(credentials_path),
                "--mountpoint", str(MOUNTPOINT),
                "--silent",
            ],
            log_file,
            on_output,
        )
        if returncode != 0:
            raise InstallError(f"archinstall exited with status {returncode}", log_path)

        on_output("archinstall finished. Running post-install configuration...")

        target_setup_dir = MOUNTPOINT / CHROOT_SETUP_DIR_IN_TARGET.relative_to("/")
        target_setup_dir.mkdir(parents=True, exist_ok=True)
        for script in CHROOT_SETUP_SCRIPTS:
            shutil.copy2(ARCHINSTALL_DIR / script, target_setup_dir / script)

        env_updates: dict[str, str] = {
            "NVIDIA_PROPRIETARY_DRIVER": "true" if hardware.nvidia_proprietary_driver else "false",
        }
        if generated.rescue_partition_number is not None:
            env_updates["RESCUE_PARTITION"] = partition_device_path(
                state.disk_device, generated.rescue_partition_number
            )

        for script in CHROOT_SETUP_SCRIPTS:
            on_output(f"Running {script} inside the new install...")
            script_path = CHROOT_SETUP_DIR_IN_TARGET / script
            returncode = _run_logged(
                [
                    "arch-chroot",
                    str(MOUNTPOINT),
                    "env",
                    *(f"{key}={value}" for key, value in env_updates.items()),
                    "bash",
                    str(script_path),
                ],
                log_file,
                on_output,
            )
            if returncode != 0:
                raise InstallError(f"{script} exited with status {returncode}", log_path)

        shutil.rmtree(target_setup_dir, ignore_errors=True)

        on_output("Unmounting target...")
        subprocess.run(["umount", "-R", str(MOUNTPOINT)], check=True)

        on_output("Installation complete.")
