"""Runs the real install: archinstall itself, then the post-archinstall,
pre-reboot arch-chroot step (deploying aur-sync.sh, building/installing
sobarch-skel, sobarch-scripts, sobarch-limine-snapshots, and the
base-required AUR packages, deploying the first-boot units,
nvidia-setup.sh, snapper-setup.sh, rescue-iso-setup.sh, in that order)
against the still-mounted target.
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

AUR_SYNC_DIR = Path(__file__).resolve().parent.parent.parent / "scripts" / "aur-sync"
AUR_SYNC_SCRIPT_PATH_IN_TARGET = Path("/usr/local/lib/sobarch/aur-sync.sh")

# Base-required per decision 3 (no official package exists for
# either): must be present before first boot, same urgency tier as
# sobarch-skel itself, not deferred to the post-login dispatcher the
# way optional profile AUR packages are (Phase 8's install-profile-
# packages.sh). Built the same way as sobarch-skel below, via
# aur-sync.sh's --local mode against this already-fetched checkout.
#
# Read from base-required-packages.txt rather than hardcoded here: an
# already-installed system's update-config-menu.sh fetches that same
# file from GitHub to install any base-required package it's still
# missing (added to the list after that system's own install ran), so
# one file, not two hand-maintained lists that can drift.
def _read_base_aur_packages() -> list[str]:
    lines = (AUR_SYNC_DIR / "base-required-packages.txt").read_text().splitlines()
    return [stripped for line in lines if (stripped := line.split("#", 1)[0].strip())]


BASE_AUR_PACKAGES = _read_base_aur_packages()

# The first-boot units below all follow the same shape: a script under
# installer/firstboot/, deployed to /usr/local/lib/sobarch/ as part of
# the sobarch-scripts package (built alongside sobarch-skel in
# _build_and_install_base_packages below, real pacman-tracked version
# instead of a bespoke copy step), run once by its own
# ConditionPathExists-guarded oneshot .service (a failure leaves its
# marker/state unwritten, so it retries later rather than being
# silently skipped forever). Only the .service units themselves are
# still deployed directly, here, since sobarch-firstboot-skel.service
# needs __USERNAME__ substituted in per install, something a package's
# payload (identical across installs) can't do. None of this runs
# during the install session itself; it only gets deployed and enabled
# here (see README.md's Installer section for why: keeps the base
# install fast/minimal, and every profile/step behaves the same
# regardless of what it needs, e.g. network or a fresh user account).
#
# - unblock-rfkill.sh: unblocks any soft-blocked wireless radios (some
#   laptops persist a firmware/EC-level airplane-mode toggle into a
#   fresh install), ordered before NetworkManager.service so the two
#   units below actually have network to work with. Boot-enabled.
# - install-profile-packages.sh: the optional packages selected in the
#   TUI. Needs network, which (see the NetworkManager dispatcher script
#   below) is never actually up this early, so it has no [Install]
#   section and is never started at boot; only the dispatcher hook
#   starts it.
# - apply-skel.sh: deploys sobarch-skel's defaults into the new user's
#   $HOME. Boot-enabled.
# - apply-security-baseline.sh: nftables firewall, root lock, and the
#   optional SSH component, reading the ssh-enabled
#   flag write_security_flags() writes below. Same as
#   install-profile-packages.sh above: no [Install] section, dispatcher-only.
FIRSTBOOT_DIR = Path(__file__).resolve().parent.parent / "firstboot"
FIRSTBOOT_UNITS = [
    ("unblock-rfkill.sh", "sobarch-firstboot-rfkill.service"),
    ("install-profile-packages.sh", "sobarch-firstboot-packages.service"),
    ("apply-skel.sh", "sobarch-firstboot-skel.service"),
    ("apply-security-baseline.sh", "sobarch-firstboot-security.service"),
]
# Subset of FIRSTBOOT_UNITS above that actually has an [Install] section
# and should be started at boot. install-profile-packages.sh and
# apply-security-baseline.sh are deliberately left out: `systemctl
# enable` on a unit with no [Install] section fails, and running them
# at boot would just mean failing every time anyway, since the network
# they need is never up that early (see the NetworkManager dispatcher
# script below).
FIRSTBOOT_BOOT_ENABLED_SERVICES = {
    "sobarch-firstboot-rfkill.service",
    "sobarch-firstboot-skel.service",
}
FIRSTBOOT_SERVICE_DIR_IN_TARGET = Path("/etc/systemd/system")
SOBARCH_DIR_IN_TARGET = Path("/etc/sobarch")

# sobarch-scripts (see _build_and_install_base_packages below) also
# ships a NetworkManager dispatcher hook, 90-sobarch-firstboot, at
# /etc/NetworkManager/dispatcher.d/: the *only* thing that starts
# sobarch-firstboot-packages.service and
# sobarch-firstboot-security.service, firing once a connection actually
# comes up. A fresh WiFi-only install has no saved connection to
# auto-connect at boot, and even a once-connected WiFi network needs
# the user's session (and its oo7 secret store) running to reconnect,
# so in practice that never happens before login (see
# 90-sobarch-firstboot's own header comment). No per-install
# substitution needed, unlike the .service units above, so there's
# nothing left for install_runner.py itself to do for it.

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


def _deploy_aur_sync(log_file, on_output: OutputCallback) -> int:
    """Deploys aur-sync.sh onto the target as a raw file, permanently:
    the one unavoidable bootstrap step, needed right away by
    _build_and_install_base_packages below to build sobarch-scripts,
    the package that will go on to own this same path afterward
    (pacman -U replaces this bootstrap copy with a byte-identical
    packaged one; nothing behaviorally changes at that moment). Its
    pacman hook and everything else this script needs ship as part of
    that package instead of being deployed here too."""
    script_path = MOUNTPOINT / AUR_SYNC_SCRIPT_PATH_IN_TARGET.relative_to("/")
    script_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(AUR_SYNC_DIR / "aur-sync.sh", script_path)
    script_path.chmod(0o755)
    return 0


def _build_and_install_base_packages(log_file, on_output: OutputCallback) -> int:
    """Local-builds sobarch-skel, sobarch-scripts, sobarch-limine-snapshots,
    and the base-required AUR packages (localsend-bin, blesh-git, tinty-git; decision 3)
    from this checkout and installs them into the target, so
    /usr/share/sobarch/skel/, /usr/local/lib/sobarch/, and every
    package exist by the time first boot (and, for
    sobarch-limine-snapshots, snapper-setup.sh right after this) runs.
    Goes through the real aur-sync.sh (--local mode, against this
    already-fetched checkout, no curl refetch needed) rather than a
    bespoke build routine, so there's exactly one place that knows how
    to build a vendored package; aur-sync.sh itself creates and builds
    as its own unprivileged build user, so nothing here needs to run as
    (or chown to) the newly created human account.

    sobarch-scripts is built here too, not just deployed as a raw file
    the way it was before real pacman version tracking existed for it:
    its own package() is what puts apply-skel.sh, durable-replace.sh,
    and the rest of installer/firstboot/*.sh (plus aur-sync.sh itself)
    at /usr/local/lib/sobarch/, so the loop below no longer needs to
    copy those scripts in by hand.

    sobarch-skel's PKGBUILD reaches out to ../../../skel, and
    sobarch-scripts' to ../../../installer/firstboot and
    ../../../scripts/aur-sync, both via a relative path, so those
    directories must be staged alongside their package directories
    here, not just the package directories in isolation."""
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
    shutil.copytree(REPO_ROOT / "installer" / "firstboot", build_dir / "installer" / "firstboot")
    shutil.copytree(REPO_ROOT / "scripts" / "aur-sync", build_dir / "scripts" / "aur-sync")
    for pkg in BASE_AUR_PACKAGES:
        shutil.copytree(REPO_ROOT / "packages" / "aur" / pkg, build_dir / "packages" / "aur" / pkg)

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

        on_output("Deploying the AUR sync mechanism...")
        returncode = _deploy_aur_sync(log_file, on_output)
        if returncode != 0:
            raise InstallError("failed to deploy aur-sync.sh", log_path)

        on_output("Building and installing sobarch-skel, sobarch-scripts, sobarch-limine-snapshots, and base-required AUR packages...")
        returncode = _build_and_install_base_packages(log_file, on_output)
        if returncode != 0:
            raise InstallError("failed to build/install base packages", log_path)

        write_firstboot_package_lists(state, MOUNTPOINT / SOBARCH_DIR_IN_TARGET.relative_to("/"))
        write_security_flags(state, MOUNTPOINT / SOBARCH_DIR_IN_TARGET.relative_to("/"))

        # /usr/local/lib/sobarch/ itself already exists by this point:
        # the sobarch-scripts package built and installed above put it
        # there, along with apply-skel.sh, durable-replace.sh, and the
        # rest of installer/firstboot/*.sh; only the per-install
        # .service units are templated and deployed here.
        firstboot_service_dir = MOUNTPOINT / FIRSTBOOT_SERVICE_DIR_IN_TARGET.relative_to("/")
        firstboot_service_dir.mkdir(parents=True, exist_ok=True)

        service_names = []
        for _script_name, service_name in FIRSTBOOT_UNITS:
            # __USERNAME__ only appears in sobarch-firstboot-skel.service
            # (it must run as the new account, not root, to write into
            # its $HOME); plain text substitution on the rest is a no-op.
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
