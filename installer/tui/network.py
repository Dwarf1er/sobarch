"""Live-environment connectivity check and iwctl WiFi connect.

iwctl has no machine-readable output, so its tables are parsed best-effort.
"""

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
    """Fetch a real URL, since a route can exist with no internet behind it."""
    result = _run(
        ["curl", "-fsS", "--max-time", str(CONNECTIVITY_CHECK_TIMEOUT_SECONDS), "-o", "/dev/null", CONNECTIVITY_CHECK_URL],
        timeout=CONNECTIVITY_CHECK_TIMEOUT_SECONDS + 2,
    )
    return result.returncode == 0


def list_station_devices() -> list[str]:
    """Wireless adapters in station mode."""
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
    """Scan and list networks; returns [] on any failure (manual SSID entry is the fallback)."""
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
            # Security and signal are the last two fields; the SSID may contain spaces.
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
