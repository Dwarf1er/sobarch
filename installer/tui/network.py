"""Live-environment network connectivity: a real reachability check
plus iwd/iwctl-driven WiFi connect, for hardware with no wired link.
Direct subprocess calls (mirroring disks.py's style), not a shell
script: iwctl/curl/ip already do everything needed without an
intermediate parser layer of our own.

iwctl has no JSON output mode (checked `iwctl --help` directly -- no
such flag exists), unlike `lsblk -J` disks.py already relies on. Its
table output is ANSI-colored text; scan_networks() below is
best-effort against that format and degrades to an empty list rather
than raising, since this can't be validated against real WiFi hardware
in every environment this runs in."""

import re
import subprocess
import time
from dataclasses import dataclass

CONNECTIVITY_CHECK_URL = "https://archlinux.org"
CONNECTIVITY_CHECK_TIMEOUT_SECONDS = 3

_ANSI_ESCAPE = re.compile(r"\x1b\[[0-9;]*m")


@dataclass
class NetworkInfo:
    ssid: str
    security: str
    signal: str


def _run(args: list[str], timeout: float | None = None) -> subprocess.CompletedProcess:
    return subprocess.run(args, capture_output=True, text=True, timeout=timeout, check=False)


def _strip_ansi(text: str) -> str:
    return _ANSI_ESCAPE.sub("", text)


def is_connected() -> bool:
    """A real reachability check (DNS + TLS + HTTP), not just "is
    there a route" -- a route can exist with no actual upstream, e.g.
    an access point with no internet behind it."""
    result = _run(
        ["curl", "-fsS", "--max-time", str(CONNECTIVITY_CHECK_TIMEOUT_SECONDS), "-o", "/dev/null", CONNECTIVITY_CHECK_URL],
        timeout=CONNECTIVITY_CHECK_TIMEOUT_SECONDS + 2,
    )
    return result.returncode == 0


def list_station_devices() -> list[str]:
    """Wireless adapters in station (client) mode. Only the first one
    found is ever used by this screen -- multiple WiFi adapters on one
    machine is out of scope."""
    result = _run(["iwctl", "station", "list"])
    devices = []
    for line in _strip_ansi(result.stdout).splitlines():
        line = line.strip()
        if not line or line.startswith("-") or line.startswith("Name") or line.startswith("Devices"):
            continue
        name = line.split()[0]
        if name:
            devices.append(name)
    return devices


def scan_networks(device: str, max_wait_seconds: float = 10.0) -> list[NetworkInfo]:
    """Best-effort: triggers a scan, waits for it to finish (bounded,
    not indefinitely), then parses `get-networks`. Any failure here
    just means the caller gets an empty list -- manual SSID entry is
    always the real fallback, this is a convenience on top."""
    try:
        _run(["iwctl", "station", device, "scan"])

        deadline = time.monotonic() + max_wait_seconds
        while time.monotonic() < deadline:
            show = _run(["iwctl", "station", device, "show"])
            if "Scanning" not in _strip_ansi(show.stdout) or "yes" not in _strip_ansi(show.stdout).lower():
                break
            time.sleep(0.5)

        result = _run(["iwctl", "station", device, "get-networks"])
        networks = []
        for line in _strip_ansi(result.stdout).splitlines():
            line = line.strip()
            if not line or line.startswith("-") or line.startswith("Network") or line.startswith("Available"):
                continue
            # Columns are right-padded and separated by variable
            # whitespace; the security token (psk/open/8021x/...) is
            # always the second-to-last field, signal bars/dBm last,
            # and the SSID is everything before that -- more robust
            # than splitting on fixed column widths, which drift with
            # SSID length.
            parts = line.split()
            if len(parts) < 3:
                continue
            ssid = " ".join(parts[:-2])
            security, signal = parts[-2], parts[-1]
            if ssid:
                networks.append(NetworkInfo(ssid=ssid, security=security, signal=signal))
        return networks
    except (subprocess.SubprocessError, OSError):
        return []


def connect(device: str, ssid: str, passphrase: str) -> tuple[bool, str]:
    result = _run(
        ["iwctl", "--passphrase", passphrase, "--dont-ask", "station", device, "connect", ssid],
        timeout=30,
    )
    if result.returncode == 0:
        return True, ""
    message = _strip_ansi(result.stderr).strip() or _strip_ansi(result.stdout).strip() or "Connection failed."
    return False, message
