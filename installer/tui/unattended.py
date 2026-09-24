"""Unattended install: builds a WizardState from a JSON answer file
instead of the interactive wizard screens, then drives the exact same
generate_configs()/run_install() pair ReviewScreen/ProgressScreen call,
with plain print()s standing in for the TUI's log widget.

Deliberately scoped down from what the wizard supports, rather than
mirroring every screen:

- No dual-boot/free-space install. Reusing an existing ESP or a
  detected free-space gap (screens/disk.py, disk_probe.py) is exactly
  the kind of judgment call disk_probe.py's own free-space floor and
  ESP-detection heuristics were written for a human to confirm on the
  review screen, not to run blind on unknown hardware.
- Whole-profile selection only (a list of profile slugs), not the
  per-package granularity screens/profiles.py offers -- there's no
  real use case yet for picking individual packages out of a profile
  without a human present to do it.

No network fetch of the answer file here: __main__.py takes
--answer-file as a local path, staged on the live ISO however the
operator got it there. PXE-netbooting the official installer artifacts
straight into this path is documented (website/content/docs/installer/
pxe-netboot.md), by chaining a PXE-side wrapper script into the same
bootstrap.sh --answer-file invocation a human would otherwise type; a
first-party fetch of the answer file itself over the network (so one
PXE menu entry doesn't need an operator-hosted wrapper script) is still
not built -- see docs/DECISIONS.md decision #18.
"""

import json
import os
import sys
from pathlib import Path

from config_gen import (
    ConfigGenError,
    generate_configs,
    write_configs,
    write_firstboot_package_lists,
    write_git_config,
    write_profile_selection,
    write_security_flags,
)
from disks import list_disks
from hardware import HardwareInfo, detect_hardware
from install_runner import InstallError, run_install
from profiles_data import PROFILES
from state import WizardState
from validators import EMAIL_RE, HOSTNAME_RE, USERNAME_RE

_REQUIRED_FIELDS = ("disk", "hostname", "username")
_SLUG_TO_PROFILE = {profile.slug: profile for profile in PROFILES}


class UnattendedConfigError(Exception):
    pass


def _resolve_disk(selector: str) -> tuple[str, int]:
    disks = list_disks()
    if not disks:
        raise UnattendedConfigError("no disks detected")

    if selector == "largest":
        chosen = max(disks, key=lambda disk: disk.size_bytes)
        return chosen.path, chosen.size_bytes

    for disk in disks:
        if disk.path == selector:
            return disk.path, disk.size_bytes

    available = ", ".join(disk.path for disk in disks)
    raise UnattendedConfigError(f"disk {selector!r} not found (available: {available})")


def _resolve_profiles(slugs: object) -> dict[str, list[str]]:
    if slugs is None:
        return {}
    if not isinstance(slugs, list) or not all(isinstance(slug, str) for slug in slugs):
        raise UnattendedConfigError("'profiles' must be a list of profile slugs")

    selection: dict[str, list[str]] = {}
    for slug in slugs:
        profile = _SLUG_TO_PROFILE.get(slug)
        if profile is None:
            available = ", ".join(sorted(_SLUG_TO_PROFILE))
            raise UnattendedConfigError(f"unknown profile slug {slug!r} (available: {available})")
        selection[profile.name] = [pkg.name for pkg in profile.packages]
    return selection


def build_state(data: dict) -> WizardState:
    missing = [key for key in _REQUIRED_FIELDS if not data.get(key)]
    if missing:
        raise UnattendedConfigError(f"answer file is missing required field(s): {', '.join(missing)}")

    password = str(data.get("password", ""))
    password_hash = str(data.get("password_hash", ""))
    if bool(password) == bool(password_hash):
        raise UnattendedConfigError("answer file must set exactly one of 'password' or 'password_hash'")

    hostname = str(data["hostname"])
    if not HOSTNAME_RE.match(hostname):
        raise UnattendedConfigError(f"invalid hostname: {hostname!r}")

    username = str(data["username"])
    if not USERNAME_RE.match(username):
        raise UnattendedConfigError(f"invalid username: {username!r}")

    git_name = str(data.get("git_name", ""))
    git_email = str(data.get("git_email", ""))
    if bool(git_name) != bool(git_email):
        raise UnattendedConfigError("git_name and git_email must both be set, or both left blank")
    if git_email and not EMAIL_RE.match(git_email):
        raise UnattendedConfigError(f"invalid git_email: {git_email!r}")

    disk_device, disk_size_bytes = _resolve_disk(str(data["disk"]))

    return WizardState(
        disk_device=disk_device,
        disk_size_bytes=disk_size_bytes,
        hostname=hostname,
        username=username,
        password=password,
        password_hash=password_hash,
        kb_layout=str(data.get("kb_layout", "us")),
        sys_lang=str(data.get("sys_lang", "en_US.UTF-8")),
        timezone=str(data.get("timezone", "UTC")),
        mirror_region=str(data.get("mirror_region", "")),
        rescue_media=bool(data.get("rescue_media", True)),
        ssh_enabled=bool(data.get("ssh_enabled", False)),
        disk_encryption_enabled=bool(data.get("encryption_password")),
        disk_encryption_password=str(data.get("encryption_password", "")),
        git_name=git_name,
        git_email=git_email,
        install_everything=bool(data.get("install_everything", False)),
        profile_packages=_resolve_profiles(data.get("profiles")),
    )


def _write_dry_run_configs(state: WizardState, hardware: HardwareInfo, output_dir: Path) -> None:
    generated = generate_configs(state, hardware)
    write_configs(generated, output_dir)
    write_profile_selection(state, output_dir)
    write_firstboot_package_lists(state, output_dir)
    write_security_flags(state, output_dir)
    write_git_config(state, output_dir)


def run_unattended(answer_path: Path, output_dir: Path, dry_run: bool) -> int:
    try:
        data = json.loads(answer_path.read_text())
    except OSError as error:
        print(f"sobarch: can't read answer file {answer_path}: {error}", file=sys.stderr)
        return 1
    except json.JSONDecodeError as error:
        print(f"sobarch: {answer_path} is not valid JSON: {error}", file=sys.stderr)
        return 1

    hardware = detect_hardware()

    try:
        state = build_state(data)
    except UnattendedConfigError as error:
        print(f"sobarch: {error}", file=sys.stderr)
        return 1

    if dry_run:
        try:
            _write_dry_run_configs(state, hardware, output_dir)
        except ConfigGenError as error:
            print(f"sobarch: {error}", file=sys.stderr)
            return 1
        print(f"sobarch: --dry-run, config written to {output_dir}")
        return 0

    if os.geteuid() != 0:
        print("sobarch: must run as root to install (pass --dry-run to only generate the config)", file=sys.stderr)
        return 1

    try:
        generated = generate_configs(state, hardware)
    except ConfigGenError as error:
        print(f"sobarch: {error}", file=sys.stderr)
        return 1

    try:
        run_install(state, hardware, generated, output_dir, on_output=print)
    except InstallError as error:
        print(f"sobarch: install failed: {error}\nFull log: {error.log_path}", file=sys.stderr)
        return 1

    print("sobarch: installation complete. Reboot when ready (systemctl reboot).")
    return 0
