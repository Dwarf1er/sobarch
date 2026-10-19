"""Field-validation regexes shared by the wizard sections and unattended.py."""

import re

HOSTNAME_RE = re.compile(r"^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$")
USERNAME_RE = re.compile(r"^[a-z_][a-z0-9_-]*$")
EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
