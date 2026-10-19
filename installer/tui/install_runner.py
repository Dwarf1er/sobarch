"""Runs archinstall, then the post-install arch-chroot steps against the mounted target."""

import shutil
import subprocess
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

from config_gen import (
    GeneratedConfig,
    partition_device_path,
    write_configs,
    write_firstboot_package_lists,
    write_git_config,
    write_security_flags,
)
from hardware import HardwareInfo
from state import WizardState

MOUNTPOINT = Path("/mnt")
ARCHINSTALL_DIR = Path(__file__).resolve().parent.parent / "archinstall"
CHROOT_SETUP_SCRIPTS = [
    "nvidia-setup.sh",
    "snapper-setup.sh",
    "limine-theme-setup.sh",
    "plymouth-setup.sh",
    "rescue-iso-setup.sh",
    "ly-theme-setup.sh",
    "power-setup.sh",
]
CHROOT_SETUP_DIR_IN_TARGET = Path("/root/sobarch-setup")

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
# Not /tmp: arch-chroot mounts a fresh tmpfs there on every call.
SOBARCH_SKEL_BUILD_DIR_IN_TARGET = Path("/var/tmp/sobarch-skel-build")

AUR_SYNC_DIR = Path(__file__).resolve().parent.parent.parent / "scripts" / "aur-sync"
AUR_SYNC_SCRIPT_PATH_IN_TARGET = Path("/usr/local/lib/sobarch/aur-sync.sh")

# AUR packages needed before first boot. update-system.sh reads the same file.
def _read_base_aur_packages() -> list[str]:
    lines = (AUR_SYNC_DIR / "base-required-packages.txt").read_text().splitlines()
    return [stripped for line in lines if (stripped := line.split("#", 1)[0].strip())]


BASE_AUR_PACKAGES = _read_base_aur_packages()

# The scripts ship in sobarch-scripts; only the .service units are deployed here,
# since some need __USERNAME__ substituted per install.
FIRSTBOOT_DIR = Path(__file__).resolve().parent.parent / "firstboot"
FIRSTBOOT_UNITS = [
    ("unblock-rfkill.sh", "sobarch-firstboot-rfkill.service"),
    ("install-profile-packages.sh", "sobarch-firstboot-packages.service"),
    ("apply-skel.sh", "sobarch-firstboot-skel.service"),
    ("apply-security-baseline.sh", "sobarch-firstboot-security.service"),
    ("apply-git-setup.sh", "sobarch-firstboot-git.service"),
    ("setup-rescue-iso.sh", "sobarch-firstboot-rescue.service"),
]
# The rest need network and have no [Install] section; the NetworkManager
# dispatcher hook in sobarch-scripts starts them once a connection is up.
FIRSTBOOT_BOOT_ENABLED_SERVICES = {
    "sobarch-firstboot-rfkill.service",
    "sobarch-firstboot-skel.service",
    "sobarch-firstboot-git.service",
}
FIRSTBOOT_SERVICE_DIR_IN_TARGET = Path("/etc/systemd/system")
SOBARCH_DIR_IN_TARGET = Path("/etc/sobarch")

OutputCallback = Callable[[str], None]


class _PhaseTimer:
    """Logs wall-clock time per install phase and prints a summary."""

    def __init__(self, log_file, on_output: OutputCallback):
        self._log_file = log_file
        self._on_output = on_output
        self._phases: list[tuple[str, float]] = []
        self._label: str | None = None
        self._started = 0.0

    def start(self, label: str) -> None:
        self.stop()
        self._label = label
        self._started = time.monotonic()

    def stop(self) -> None:
        if self._label is None:
            return
        elapsed = time.monotonic() - self._started
        self._phases.append((self._label, elapsed))
        self._log_file.write(f"[timing] {self._label}: {elapsed:.1f}s\n")
        self._log_file.flush()
        self._label = None

    def summary(self) -> None:
        self.stop()
        total = sum(elapsed for _, elapsed in self._phases)
        lines = [f"  {label}: {elapsed:.0f}s" for label, elapsed in self._phases]
        lines.append(f"  total: {total:.0f}s")
        text = "Install timing:\n" + "\n".join(lines)
        self._log_file.write(text + "\n")
        self._on_output(text)


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


def _deploy_aur_sync(log_file, on_output: OutputCallback) -> int:
    """Copy aur-sync.sh in raw so it can build sobarch-scripts, which then owns it."""
    script_path = MOUNTPOINT / AUR_SYNC_SCRIPT_PATH_IN_TARGET.relative_to("/")
    script_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(AUR_SYNC_DIR / "aur-sync.sh", script_path)
    script_path.chmod(0o755)
    return 0


def _stage_vendored_package(pkg: str, build_dir: Path) -> None:
    """Copy one package from packages/aur/ or packages/custom/ into build_dir."""
    for kind in ("aur", "custom"):
        source = REPO_ROOT / "packages" / kind / pkg
        if source.is_dir():
            shutil.copytree(source, build_dir / "packages" / kind / pkg)
            return
    raise FileNotFoundError(f"base-required package {pkg} is in neither packages/aur/ nor packages/custom/")


def _build_and_install_base_packages(log_file, on_output: OutputCallback) -> int:
    """Build and install the custom and base-required AUR packages via aur-sync.sh --local.

    The PKGBUILDs reach skel/, branding/, installer/ and scripts/ by relative
    path, so those are staged alongside the package directories.
    """
    build_dir = MOUNTPOINT / SOBARCH_SKEL_BUILD_DIR_IN_TARGET.relative_to("/")
    shutil.rmtree(build_dir, ignore_errors=True)
    shutil.copytree(REPO_ROOT / "packages" / "custom" / "sobarch-skel", build_dir / "packages" / "custom" / "sobarch-skel")
    shutil.copytree(
        REPO_ROOT / "packages" / "custom" / "sobarch-limine-snapshots",
        build_dir / "packages" / "custom" / "sobarch-limine-snapshots",
    )
    shutil.copytree(
        REPO_ROOT / "packages" / "custom" / "sobarch-scripts",
        build_dir / "packages" / "custom" / "sobarch-scripts",
    )
    shutil.copytree(REPO_ROOT / "skel", build_dir / "skel")
    shutil.copytree(REPO_ROOT / "branding", build_dir / "branding")
    shutil.copytree(REPO_ROOT / "installer" / "firstboot", build_dir / "installer" / "firstboot")
    shutil.copytree(REPO_ROOT / "installer" / "archinstall", build_dir / "installer" / "archinstall")
    shutil.copytree(REPO_ROOT / "scripts", build_dir / "scripts")
    for pkg in BASE_AUR_PACKAGES:
        _stage_vendored_package(pkg, build_dir)

    returncode = _run_logged(
        [
            "arch-chroot", str(MOUNTPOINT),
            str(AUR_SYNC_SCRIPT_PATH_IN_TARGET),
            "--local", str(SOBARCH_SKEL_BUILD_DIR_IN_TARGET),
            "sobarch-skel", "sobarch-scripts", "sobarch-limine-snapshots", *BASE_AUR_PACKAGES,
        ],
        log_file,
        on_output,
    )

    shutil.rmtree(build_dir, ignore_errors=True)
    return returncode


# One aur-sync call each, in this order: aur-sync sorts targets by name, which
# would put lib32-nvidia-580xx-utils before the package it depends on.
NVIDIA_LEGACY_PACKAGES = ("nvidia-580xx-utils", "lib32-nvidia-580xx-utils")


def _install_nvidia_legacy_driver(log_file, on_output: OutputCallback) -> int:
    """Build the AUR-only 580xx driver for Maxwell/Pascal/Volta GPUs."""
    build_dir = MOUNTPOINT / SOBARCH_SKEL_BUILD_DIR_IN_TARGET.relative_to("/")
    shutil.rmtree(build_dir, ignore_errors=True)
    for pkg in NVIDIA_LEGACY_PACKAGES:
        shutil.copytree(REPO_ROOT / "packages" / "aur" / pkg, build_dir / "packages" / "aur" / pkg)

    returncode = 0
    for pkg in NVIDIA_LEGACY_PACKAGES:
        returncode = _run_logged(
            [
                "arch-chroot", str(MOUNTPOINT),
                str(AUR_SYNC_SCRIPT_PATH_IN_TARGET),
                "--local", str(SOBARCH_SKEL_BUILD_DIR_IN_TARGET),
                pkg,
            ],
            log_file,
            on_output,
        )
        if returncode != 0:
            break

    shutil.rmtree(build_dir, ignore_errors=True)
    return returncode


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

        timer = _PhaseTimer(log_file, on_output)

        timer.start("archinstall (partition, pacstrap, base config)")
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
        # Holds the LUKS passphrase in plaintext; a retry regenerates it.
        credentials_path.unlink(missing_ok=True)
        if returncode != 0:
            raise InstallError(f"archinstall exited with status {returncode}", log_path)

        on_output("archinstall finished. Running post-install configuration...")

        timer.start("deploy aur-sync")
        on_output("Deploying the AUR sync mechanism...")
        returncode = _deploy_aur_sync(log_file, on_output)
        if returncode != 0:
            raise InstallError("failed to deploy aur-sync.sh", log_path)

        timer.start("base package build/install")
        on_output("Building and installing sobarch-skel, sobarch-scripts, sobarch-limine-snapshots, and base-required AUR packages...")
        returncode = _build_and_install_base_packages(log_file, on_output)
        if returncode != 0:
            raise InstallError("failed to build/install base packages", log_path)

        if hardware.nvidia_legacy_580xx:
            timer.start("NVIDIA 580xx build")
            on_output("Building the NVIDIA 580xx legacy driver (this takes a while)...")
            returncode = _install_nvidia_legacy_driver(log_file, on_output)
            if returncode != 0:
                raise InstallError("failed to build/install the NVIDIA 580xx driver", log_path)

        timer.start("first-boot unit deployment")
        write_firstboot_package_lists(state, MOUNTPOINT / SOBARCH_DIR_IN_TARGET.relative_to("/"))
        write_security_flags(state, MOUNTPOINT / SOBARCH_DIR_IN_TARGET.relative_to("/"))
        write_git_config(state, MOUNTPOINT / SOBARCH_DIR_IN_TARGET.relative_to("/"))

        firstboot_service_dir = MOUNTPOINT / FIRSTBOOT_SERVICE_DIR_IN_TARGET.relative_to("/")
        firstboot_service_dir.mkdir(parents=True, exist_ok=True)

        service_names = []
        for _script_name, service_name in FIRSTBOOT_UNITS:
            service_text = (FIRSTBOOT_DIR / service_name).read_text().replace("__USERNAME__", state.username)
            (firstboot_service_dir / service_name).write_text(service_text)
            service_names.append(service_name)

        on_output("Enabling first-boot units...")
        enable_names = [name for name in service_names if name in FIRSTBOOT_BOOT_ENABLED_SERVICES]
        returncode = _run_logged(
            ["arch-chroot", str(MOUNTPOINT), "systemctl", "enable", *enable_names],
            log_file,
            on_output,
        )
        if returncode != 0:
            raise InstallError("failed to enable first-boot units", log_path)

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
        if generated.rescue_boot_partition_number is not None:
            env_updates["RESCUE_BOOT_PARTITION"] = partition_device_path(
                state.disk_device, generated.rescue_boot_partition_number
            )
        elif generated.rescue_boot_merged:
            env_updates["RESCUE_BOOT_MERGED"] = "true"

        for script in CHROOT_SETUP_SCRIPTS:
            timer.start(script)
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

        timer.start("unmount")
        on_output("Unmounting target...")
        subprocess.run(["umount", "-R", str(MOUNTPOINT)], check=True)

        timer.summary()
        on_output("Installation complete.")
