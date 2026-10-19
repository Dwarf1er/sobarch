"""The wizard's answers, turned into archinstall config by config_gen.py."""

from dataclasses import dataclass, field


@dataclass
class WizardState:
    disk_device: str | None = None
    disk_size_bytes: int | None = None

    # Install into existing free space instead of wiping the disk.
    free_space_install: bool = False
    free_space_start_bytes: int | None = None
    free_space_size_bytes: int | None = None
    free_space_at_disk_end: bool = False

    hostname: str = ""
    username: str = ""
    password: str = ""
    # Pre-hashed password from an unattended answer file; used instead of `password`.
    password_hash: str = ""

    kb_layout: str = "us"
    sys_lang: str = "en_US.UTF-8"
    timezone: str = "UTC"
    # Empty keeps the live ISO's reflector-ranked mirrorlist.
    mirror_regions: list[str] = field(default_factory=list)

    rescue_media: bool = True

    # LUKS on the root partition only; the ESP must stay unencrypted.
    disk_encryption_enabled: bool = False
    disk_encryption_password: str = ""

    ssh_enabled: bool = False

    # Both blank skips git config; an SSH key is still generated.
    git_name: str = ""
    git_email: str = ""

    install_everything: bool = False
    # Profile name -> selected packages. install_everything is resolved at output time.
    profile_packages: dict[str, list[str]] = field(default_factory=dict)

    def is_complete(self) -> bool:
        return bool(
            self.disk_device
            and self.hostname
            and self.username
            and (self.password or self.password_hash)
        )
