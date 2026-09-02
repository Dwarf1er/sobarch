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

    profiles: list[str] = field(default_factory=list)

    def is_complete(self) -> bool:
        return bool(self.disk_device and self.hostname and self.username and self.password)
