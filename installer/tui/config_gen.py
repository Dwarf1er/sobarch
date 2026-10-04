"""Turns a WizardState + HardwareInfo into the two real archinstall
config files (base.json, credentials.json), by editing the installer's
JSON templates as parsed JSON rather than by text substitution: several
of the required edits (dropping the rescue partitions, shifting the
BTRFS partition's start, computing its exact byte size, appending
detected packages) are structural, not simple token replacement, so the
whole pass is done the same way once we're already parsing the JSON
anyway."""

import json
import os
from dataclasses import dataclass
from pathlib import Path

from archinstall.lib.crypt import crypt_yescrypt

from hardware import HardwareInfo
from profiles_data import resolve_selection, split_by_source
from state import WizardState

ARCHINSTALL_DIR = Path(__file__).resolve().parent.parent / "archinstall"
BASE_JSON_TEMPLATE = ARCHINSTALL_DIR / "base.json"
CREDENTIALS_JSON_TEMPLATE = ARCHINSTALL_DIR / "credentials.json"

MIB = 1024 * 1024

# GPT's secondary header and partition table occupy the last 33 LBA
# sectors of the disk (33 * 512 = 16896 bytes). Reserving a full MiB
# here, the same alignment already used for every partition's start
# offset in base.json, is simpler than computing the exact tail and
# leaves comfortable room for it either way.
GPT_TRAILING_RESERVE_BYTES = MIB


class ConfigGenError(Exception):
    pass


@dataclass
class GeneratedConfig:
    base: dict
    credentials: dict
    rescue_partition_number: int | None
    rescue_boot_partition_number: int | None
    rescue_boot_merged: bool


def _to_mib(size_or_start: dict) -> int:
    unit = size_or_start["unit"]
    value = int(size_or_start["value"])
    if unit == "MiB":
        return value
    if unit == "GiB":
        return value * 1024
    raise ConfigGenError(f"unexpected unit {unit!r} in base.json template")


def _mib_dict(template: dict, value_mib: int) -> dict:
    """Same {sector_size, unit: MiB, value} shape used throughout
    base.json's partition entries, keyed off an existing dict's own
    sector_size rather than a hardcoded 512, in case a future template
    partition uses a different one."""
    return {
        "sector_size": template["sector_size"],
        "unit": "MiB",
        "value": value_mib,
    }


def partition_device_path(disk_device: str, partition_number: int) -> str:
    """/dev/sda -> /dev/sda1, but /dev/nvme0n1 -> /dev/nvme0n1p1: any
    device path ending in a digit needs a "p" separator before the
    partition number, or the kernel-assigned name would be ambiguous."""
    if disk_device[-1].isdigit():
        return f"{disk_device}p{partition_number}"
    return f"{disk_device}{partition_number}"


def generate_configs(state: WizardState, hardware: HardwareInfo) -> GeneratedConfig:
    if not state.disk_device or state.disk_size_bytes is None:
        raise ConfigGenError("a disk must be selected before generating a config")

    base = json.loads(BASE_JSON_TEMPLATE.read_text())
    credentials = json.loads(CREDENTIALS_JSON_TEMPLATE.read_text())

    device_mod = base["disk_config"]["device_modifications"][0]
    device_mod["device"] = state.disk_device
    partitions = device_mod["partitions"]

    boot = next(p for p in partitions if "boot" in p.get("flags", []))
    rescue = next((p for p in partitions if p.get("fs_type") == "ext4"), None)
    # The small FAT32 partition holding the rescue entry's extracted
    # vmlinuz/initramfs, distinguished from the ESP by *not* carrying the
    # boot/esp flags (both are fs_type "fat32").
    rescue_boot = next(
        (p for p in partitions if p.get("fs_type") == "fat32" and "boot" not in p.get("flags", [])), None
    )
    btrfs = next(p for p in partitions if p.get("fs_type") == "btrfs")

    rescue_partition_number = None
    rescue_boot_partition_number = None
    rescue_boot_merged = False

    if state.free_space_install:
        # Installing alongside another OS (docs/DECISIONS.md): never
        # wipe, never shrink anything -- the free space was already
        # carved out by the user (disk_probe.py only offered this
        # option because it found enough of it). rescue_media is
        # forced False by sections/disk.py for this path, so the rescue
        # partitions are always dropped, same as the ordinary
        # no-rescue-media branch below.
        if rescue is not None:
            partitions.remove(rescue)
        if rescue_boot is not None:
            partitions.remove(rescue_boot)

        device_mod["wipe"] = False
        assert state.free_space_start_bytes is not None and state.free_space_size_bytes is not None
        # Align inward, never outward: the start rounds up and the end
        # rounds down, so the new partitions can never reach into the
        # neighbouring partition when the gap's own edges aren't
        # MiB-aligned (a shrunk Windows partition's end usually isn't).
        free_space_start_mib = -(-state.free_space_start_bytes // MIB)
        free_space_end_mib = (state.free_space_start_bytes + state.free_space_size_bytes) // MIB

        # sobarch always gets its own ESP, created at the start of the
        # free space, never the other OS's: /boot IS the ESP here, so
        # sharing a (typically 100-260 MB) Windows ESP would let kernel
        # and initramfs updates fill it, and Limine's removable-path
        # install (EFI/BOOT/BOOTX64.EFI) would overwrite any fallback
        # loader already on it. The other OS's boot files are never
        # touched; limine-add-os-entry.sh chainloads it from its own ESP.
        boot["start"] = _mib_dict(boot["start"], free_space_start_mib)
        btrfs_start_mib = free_space_start_mib + _to_mib(boot["size"])

        root_size_mib = free_space_end_mib - btrfs_start_mib
        # The GPT-tail reserve only matters when the free space runs to
        # the physical end of the disk; a gap between two existing
        # partitions needs no such reserve.
        if state.free_space_at_disk_end:
            root_size_mib -= GPT_TRAILING_RESERVE_BYTES // MIB
    else:
        boot_end_mib = _to_mib(boot["start"]) + _to_mib(boot["size"])

        if state.rescue_media:
            if rescue is None or rescue_boot is None:
                raise ConfigGenError("rescue media was requested but base.json has no rescue partition template")
            if hardware.is_uefi:
                btrfs_start_mib = boot_end_mib + _to_mib(rescue_boot["size"]) + _to_mib(rescue["size"])
                rescue_boot_partition_number = partitions.index(rescue_boot) + 1
                rescue_partition_number = partitions.index(rescue) + 1
            else:
                # archinstall picks MBR (not GPT) for a BIOS install, and
                # caps it at 3 primary partitions -- one over budget with a
                # dedicated rescue-boot partition alongside boot/rescue/root.
                # The rescue kernel/initramfs live directly under /boot
                # instead (installer/archinstall/rescue-iso-setup.sh writes
                # them to /boot/rescue/ rather than formatting a separate
                # partition), dropping the count back to 3.
                partitions.remove(rescue_boot)
                rescue["start"] = _mib_dict(rescue["start"], boot_end_mib)
                btrfs_start_mib = boot_end_mib + _to_mib(rescue["size"])
                rescue_partition_number = partitions.index(rescue) + 1
                rescue_boot_merged = True
        else:
            if rescue is not None:
                partitions.remove(rescue)
            if rescue_boot is not None:
                partitions.remove(rescue_boot)
            btrfs_start_mib = boot_end_mib

        root_size_mib = (state.disk_size_bytes - (btrfs_start_mib * MIB) - GPT_TRAILING_RESERVE_BYTES) // MIB

    if root_size_mib <= 0:
        raise ConfigGenError("the selected disk is too small for this partition layout")

    btrfs["start"] = _mib_dict(btrfs["start"], btrfs_start_mib)
    btrfs["size"] = _mib_dict(btrfs["size"], root_size_mib)

    if state.disk_encryption_enabled:
        # LUKS on the root (btrfs) partition only -- referenced by its
        # obj_id, the same indirection archinstall's own disk_encryption
        # schema uses instead of a device path, since a "create"
        # partition has no device path yet. The ESP (and any rescue
        # partitions) are never in this list, so they stay unencrypted:
        # required for a plain UEFI boot, and Limine's own native LUKS2
        # unlock only ever needs to open the root partition itself.
        # archinstall's own installer.py adds the mkinitcpio
        # encrypt/sd-encrypt hook and the cryptdevice= kernel parameter
        # automatically once this is set; nothing else here needs to.
        base["disk_config"]["disk_encryption"] = {
            "encryption_type": "luks",
            "partitions": [btrfs["obj_id"]],
            "lvm_volumes": [],
        }
        # Plaintext, same trust model as credentials["enc_password"]'s
        # own plaintext input (decision #18): read straight from the
        # TUI and never persisted anywhere except this output file.
        # archinstall reads it as a top-level key merged in from
        # whichever of --config/--creds carries it (lib/args.py's
        # _parse_config()), so it lives in credentials.json alongside
        # the other secret, not in base.json.
        credentials["encryption_password"] = state.disk_encryption_password

    base["hostname"] = state.hostname
    base["locale_config"]["kb_layout"] = state.kb_layout
    base["locale_config"]["sys_lang"] = state.sys_lang
    base["timezone"] = state.timezone

    if state.mirror_regions:
        # The list of URLs archinstall's MirrorRegion also carries is
        # unused by its own region lookup (it re-fetches URLs for each
        # named region live, from the same mirror-status data the TUI
        # offered these names from), so an empty list per region is enough.
        base["mirror_config"]["mirror_regions"] = {region: [] for region in state.mirror_regions}

    # Opportunistic, not ISO-detection: a plain filesystem-presence check
    # for a local package repo, baked in only by the prebuilt-ISO build
    # (scripts/iso-build/), never by the bootstrap.sh curl path. Keeps
    # the TUI agnostic about how it reached disk (decision #6) -- this
    # is inert wherever that path doesn't exist. SigLevel "Never
    # TrustAll" is safe here specifically because the repo never leaves
    # the image it's baked into. archinstall applies this to the live
    # environment's own pacman.conf (Installer.set_mirrors) before
    # pacstrap runs, so it also speeds up archinstall's own package
    # install, not just this project's post-install steps.
    sobarch_cache_db = Path("/opt/sobarch-cache/sobarch-cache.db.tar.gz")
    if sobarch_cache_db.exists():
        base["mirror_config"]["custom_repositories"] = [
            {
                "name": "sobarch-cache",
                "url": "file:///opt/sobarch-cache",
                "sign_check": "Never",
                "sign_option": "TrustAll",
            }
        ]

    base["app_config"]["bluetooth_config"]["enabled"] = hardware.bluetooth_detected

    extra_packages = {pkg for pkg in (hardware.cpu_microcode_pkg, *hardware.gpu_packages) if pkg}
    base["packages"] = sorted(set(base["packages"]) | extra_packages)

    credentials["users"][0]["username"] = state.username
    # password_hash (unattended-only, see decision #18's addendum) skips
    # this hashing step entirely -- it's already a valid enc_password
    # value, produced by the same crypt_yescrypt() call ahead of time.
    credentials["users"][0]["enc_password"] = state.password_hash or crypt_yescrypt(state.password)

    return GeneratedConfig(
        base=base,
        credentials=credentials,
        rescue_partition_number=rescue_partition_number,
        rescue_boot_partition_number=rescue_boot_partition_number,
        rescue_boot_merged=rescue_boot_merged,
    )


def write_configs(generated: GeneratedConfig, out_dir: Path) -> tuple[Path, Path]:
    out_dir.mkdir(parents=True, exist_ok=True)
    base_path = out_dir / "base.json"
    credentials_path = out_dir / "credentials.json"
    base_path.write_text(json.dumps(generated.base, indent=4) + "\n")
    # credentials.json can carry a plaintext LUKS passphrase
    # (encryption_password) alongside the account's yescrypt hash, so it
    # is created 0600 from the start: write_text() then chmod() would
    # leave a window where it exists with the umask-derived mode. The
    # chmod covers a file that already existed with a looser mode.
    fd = os.open(credentials_path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as credentials_file:
        credentials_file.write(json.dumps(generated.credentials, indent=4) + "\n")
    credentials_path.chmod(0o600)
    return base_path, credentials_path


def write_profile_selection(state: WizardState, out_dir: Path) -> Path:
    """The optional-profile answer, by profile name, kept at this
    granularity rather than flattened into one package list so
    a future consumer (the first-boot hook, and `sobarch setup
    <profile>`/`sobarch remove <profile>`, neither built yet) can still
    reason about it per profile, not just per package."""
    out_dir.mkdir(parents=True, exist_ok=True)
    path = out_dir / "profile-selection.json"
    selection = resolve_selection(state.install_everything, state.profile_packages)
    path.write_text(json.dumps(selection, indent=4) + "\n")
    return path


def write_firstboot_package_lists(state: WizardState, sobarch_dir: Path) -> tuple[Path, Path]:
    """Flat, one-package-per-line lists for installer/firstboot/
    install-profile-packages.sh to consume with plain bash on the
    installed system, no JSON/jq dependency needed there. Profile
    boundaries don't matter to that script (pacman installs a flat
    package set either way), so this flattens and dedupes across every
    selected profile, unlike write_profile_selection() above."""
    sobarch_dir.mkdir(parents=True, exist_ok=True)
    selection = resolve_selection(state.install_everything, state.profile_packages)
    all_selected = {pkg for packages in selection.values() for pkg in packages}
    official, aur = split_by_source(all_selected)

    official_path = sobarch_dir / "profile-packages-official.txt"
    aur_path = sobarch_dir / "profile-packages-aur.txt"
    official_path.write_text("".join(f"{pkg}\n" for pkg in official))
    aur_path.write_text("".join(f"{pkg}\n" for pkg in aur))
    return official_path, aur_path


def write_security_flags(state: WizardState, sobarch_dir: Path) -> Path:
    """A single flat true/false flag, read by apply-security-baseline.sh
    at first boot: SSH needs more than a package
    install (a firewall exception, a sshd_config.d drop-in), so it's
    handled by the security-baseline first-boot unit, not
    install-profile-packages.sh. Always written (never left absent), so
    a config hand-run outside the TUI has an explicit answer rather than
    relying on the first-boot script's own default."""
    sobarch_dir.mkdir(parents=True, exist_ok=True)
    path = sobarch_dir / "ssh-enabled"
    path.write_text("true\n" if state.ssh_enabled else "false\n")
    return path


def write_git_config(state: WizardState, sobarch_dir: Path) -> Path:
    """Two lines, name then email, read by apply-git-setup.sh at first
    boot. Always written, same rationale as write_security_flags() above:
    a config hand-run outside the TUI gets an explicit "skip git config"
    answer (two blank lines) rather than the first-boot script guessing.
    Blank either line means apply-git-setup.sh skips `git config
    --global user.*` entirely, but still generates the SSH key."""
    sobarch_dir.mkdir(parents=True, exist_ok=True)
    path = sobarch_dir / "git-identity"
    path.write_text(f"{state.git_name}\n{state.git_email}\n")
    return path
