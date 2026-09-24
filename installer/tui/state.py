"""The wizard's own answers, gathered one screen at a time and only
turned into an archinstall configuration once the review screen (or
--dry-run) asks for it."""

from dataclasses import dataclass, field


@dataclass
class WizardState:
    disk_device: str | None = None
    disk_size_bytes: int | None = None

    # Set together, only when the user chose "install into existing
    # free space" on screens/disk.py instead of wiping the whole disk
    # (see disk_probe.py). free_space_install is the single flag
    # config_gen.py branches on; the rest are the probe results needed
    # to place partitions without touching what's already there.
    free_space_install: bool = False
    free_space_start_bytes: int | None = None
    free_space_size_bytes: int | None = None
    free_space_at_disk_end: bool = False
    existing_esp_path: str | None = None
    existing_esp_start_bytes: int | None = None
    existing_esp_size_bytes: int | None = None

    hostname: str = ""
    username: str = ""
    password: str = ""
    # Set instead of `password` only by the unattended path (unattended.py),
    # when the answer file supplies an already-hashed `password_hash`
    # rather than plaintext -- see decision #18's addendum. Empty means
    # "hash `password` normally" (config_gen.py); the interactive wizard
    # never sets this itself.
    password_hash: str = ""

    kb_layout: str = "us"
    sys_lang: str = "en_US.UTF-8"
    timezone: str = "UTC"
    # Empty means automatic: let the live ISO's own reflector-ranked
    # mirrorlist stand, untouched (see config_gen.py). A non-empty value
    # is a country name from archinstall's own mirror-status data,
    # overriding it with a fresh, region-scoped speed test instead.
    mirror_region: str = ""

    rescue_media: bool = True

    # Opt-in LUKS encryption of the root (btrfs) partition only -- the
    # ESP always stays unencrypted (required for both a plain UEFI boot
    # and Limine's own native LUKS2 unlock), and the rescue-media
    # partitions (if any) are never encrypted either, same as the ESP.
    # Off by default, same "optional component" treatment as SSH above.
    disk_encryption_enabled: bool = False
    disk_encryption_password: str = ""

    # SSH is disabled by default: an optional
    # component, not a base-install default. Kept separate from
    # profile_packages below since enabling it needs more than
    # installing a package (a sshd_config.d drop-in, a firewall
    # exception), applied by apply-security-baseline.sh, not
    # install-profile-packages.sh.
    ssh_enabled: bool = False

    # Both blank means "skip": no user.name/user.email is written into
    # the new account's git config. An SSH key is still generated on
    # first boot regardless (see write_git_config()/apply-git-setup.sh),
    # since that needs no identity to be useful.
    git_name: str = ""
    git_email: str = ""

    install_everything: bool = False
    # Profile name -> selected package list. A profile only appears
    # here once the user has selected at least one of its packages;
    # "install everything" (above) is resolved separately, at output
    # time, rather than flattened into this dict.
    profile_packages: dict[str, list[str]] = field(default_factory=dict)

    def is_complete(self) -> bool:
        return bool(
            self.disk_device
            and self.hostname
            and self.username
            and (self.password or self.password_hash)
        )
