"""Shared field-validation regexes, used by both the interactive
wizard sections (sections/account.py, sections/options.py) and the unattended
entry point (unattended.py), so there is exactly one copy of each rule
rather than two that can drift out of sync."""

import re

HOSTNAME_RE = re.compile(r"^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$")
USERNAME_RE = re.compile(r"^[a-z_][a-z0-9_-]*$")
EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
