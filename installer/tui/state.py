"""The wizard's own answers, gathered one screen at a time and only
turned into an archinstall configuration once the review screen (or
--dry-run) asks for it."""

from dataclasses import dataclass, field


@dataclass
class WizardState:
    disk_device: str | None = None
    disk_size_bytes: int | None = None

    hostname: str = ""
    username: str = ""
    password: str = ""

    kb_layout: str = "us"
    sys_lang: str = "en_US.UTF-8"
    timezone: str = "UTC"

    rescue_media: bool = True

    # SSH is disabled by default: an optional
    # component, not a base-install default. Kept separate from
    # profile_packages below since enabling it needs more than
    # installing a package (a sshd_config.d drop-in, a firewall
    # exception), applied by apply-security-baseline.sh, not
    # install-profile-packages.sh.
    ssh_enabled: bool = False

    install_everything: bool = False
    # Profile name -> selected package list. A profile only appears
    # here once the user has selected at least one of its packages;
    # "install everything" (above) is resolved separately, at output
    # time, rather than flattened into this dict.
    profile_packages: dict[str, list[str]] = field(default_factory=dict)

    def is_complete(self) -> bool:
        return bool(self.disk_device and self.hostname and self.username and self.password)
