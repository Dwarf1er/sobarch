"""Runs the real install: archinstall itself, then the post-archinstall,
pre-reboot arch-chroot step (building/installing sobarch-skel,
deploying the first-boot units, nvidia-setup.sh, snapper-setup.sh,
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

from config_gen import (
    GeneratedConfig,
    partition_device_path,
    write_configs,
    write_firstboot_package_lists,
    write_security_flags,
)
from hardware import HardwareInfo
from state import WizardState

MOUNTPOINT = Path("/mnt")
ARCHINSTALL_DIR = Path(__file__).resolve().parent.parent / "archinstall"
CHROOT_SETUP_SCRIPTS = ["nvidia-setup.sh", "snapper-setup.sh", "rescue-iso-setup.sh"]
CHROOT_SETUP_DIR_IN_TARGET = Path("/root/sobarch-setup")

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
# Not /tmp: arch-chroot mounts a fresh, empty tmpfs over
# <target>/tmp on every single invocation (see chroot_setup() in
# /usr/bin/arch-chroot), so anything written there - by this host
# process directly, or by one arch-chroot call - is invisible to the
# next arch-chroot call. /var/tmp isn't in arch-chroot's mount list and
# is still mode 1777, so it survives across calls with the same
# build-as-non-root permissions.
SOBARCH_SKEL_BUILD_DIR_IN_TARGET = Path("/var/tmp/sobarch-skel-build")

# The first-boot units below all follow the same shape: a script under
# installer/firstboot/, deployed to /usr/local/lib/sobarch/, run once
# by its own ConditionPathExists-guarded oneshot .service (a failure
# leaves its marker/state unwritten, so it retries on the next boot
# rather than being silently skipped forever). None of this runs
# during the install session itself; it only gets deployed and enabled
# here (see README.md's Installer section for why: keeps the base
# install fast/minimal, and every profile/step behaves the same
# regardless of what it needs, e.g. network or a fresh user account).
#
# - install-profile-packages.sh: the optional packages selected in the
#   TUI.
# - apply-skel.sh: deploys sobarch-skel's defaults into the new user's
#   $HOME.
# - apply-security-baseline.sh: nftables firewall, root lock, and the
#   optional SSH component, reading
#   the ssh-enabled flag write_security_flags() writes below.
FIRSTBOOT_DIR = Path(__file__).resolve().parent.parent / "firstboot"
FIRSTBOOT_UNITS = [
    ("install-profile-packages.sh", "sobarch-firstboot-packages.service"),
    ("apply-skel.sh", "sobarch-firstboot-skel.service"),
    ("apply-security-baseline.sh", "sobarch-firstboot-security.service"),
]
FIRSTBOOT_SCRIPT_DIR_IN_TARGET = Path("/usr/local/lib/sobarch")
FIRSTBOOT_SERVICE_DIR_IN_TARGET = Path("/etc/systemd/system")
SOBARCH_DIR_IN_TARGET = Path("/etc/sobarch")

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


def _build_and_install_sobarch_skel(state: WizardState, log_file, on_output: OutputCallback) -> int:
    """Local-builds packages/custom/sobarch-skel from this checkout and
    installs it into the target, so /usr/share/sobarch/skel/ (and a
    real `pacman -Qi sobarch-skel`) exist by the time apply-skel.sh
    runs on first boot. A minimal, one-off stand-in for a general
    vendored-package build/sync mechanism that doesn't exist yet; that
    mechanism will eventually supersede this for keeping sobarch-skel
    current on an already-installed system, but something still needs
    to get it installed the very first time.

    Built as the newly created user, not root: modern makepkg refuses
    outright to run as root (no override flag), and the account
    already exists at this point (created earlier in the same
    archinstall run via credentials.json). Assumes that user's primary
    group is named the same as the username, standard useradd behavior
    (USERGROUPS_ENAB) on Arch; not yet verified against a real
    archinstall run, same as the rest of this module."""
    build_dir = MOUNTPOINT / SOBARCH_SKEL_BUILD_DIR_IN_TARGET.relative_to("/")
    shutil.rmtree(build_dir, ignore_errors=True)
    shutil.copytree(REPO_ROOT / "packages" / "custom" / "sobarch-skel", build_dir / "packages" / "custom" / "sobarch-skel")
    shutil.copytree(REPO_ROOT / "configs" / "skel", build_dir / "configs" / "skel")

    pkg_dir_in_target = SOBARCH_SKEL_BUILD_DIR_IN_TARGET / "packages" / "custom" / "sobarch-skel"

    returncode = _run_logged(
        ["arch-chroot", str(MOUNTPOINT), "chown", "-R", f"{state.username}:{state.username}", str(SOBARCH_SKEL_BUILD_DIR_IN_TARGET)],
        log_file,
        on_output,
    )
    if returncode != 0:
        return returncode

    returncode = _run_logged(
        [
            "arch-chroot", str(MOUNTPOINT),
            "runuser", "-u", state.username, "--",
            "bash", "-c", f"cd {pkg_dir_in_target} && makepkg --noconfirm",
        ],
        log_file,
        on_output,
    )
    if returncode != 0:
        return returncode

    returncode = _run_logged(
        ["arch-chroot", str(MOUNTPOINT), "bash", "-c", f"pacman -U --noconfirm {pkg_dir_in_target}/*.pkg.tar.zst"],
        log_file,
        on_output,
    )

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

        on_output("Building and installing sobarch-skel...")
        returncode = _build_and_install_sobarch_skel(state, log_file, on_output)
        if returncode != 0:
            raise InstallError("failed to build/install sobarch-skel", log_path)

        write_firstboot_package_lists(state, MOUNTPOINT / SOBARCH_DIR_IN_TARGET.relative_to("/"))
        write_security_flags(state, MOUNTPOINT / SOBARCH_DIR_IN_TARGET.relative_to("/"))

        firstboot_script_dir = MOUNTPOINT / FIRSTBOOT_SCRIPT_DIR_IN_TARGET.relative_to("/")
        firstboot_script_dir.mkdir(parents=True, exist_ok=True)
        firstboot_service_dir = MOUNTPOINT / FIRSTBOOT_SERVICE_DIR_IN_TARGET.relative_to("/")
        firstboot_service_dir.mkdir(parents=True, exist_ok=True)

        service_names = []
        for script_name, service_name in FIRSTBOOT_UNITS:
            script_path = firstboot_script_dir / script_name
            shutil.copy2(FIRSTBOOT_DIR / script_name, script_path)
            script_path.chmod(0o755)

            # __USERNAME__ only appears in sobarch-firstboot-skel.service
            # (it must run as the new account, not root, to write into
            # its $HOME); plain text substitution on the rest is a no-op.
            service_text = (FIRSTBOOT_DIR / service_name).read_text().replace("__USERNAME__", state.username)
            (firstboot_service_dir / service_name).write_text(service_text)
            service_names.append(service_name)

        on_output("Enabling first-boot units...")
        returncode = _run_logged(
            ["arch-chroot", str(MOUNTPOINT), "systemctl", "enable", *service_names],
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
