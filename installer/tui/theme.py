"""OneDark color palette, kept identical to configs/skel/.config/kitty/onedark.conf
so the installer looks like the rest of the distribution, not a different theme."""

from textual.theme import Theme

ONEDARK_BACKGROUND = "#282c34"
ONEDARK_SURFACE = "#393e48"
ONEDARK_FOREGROUND = "#abb2bf"
ONEDARK_RED = "#e06c75"
ONEDARK_GREEN = "#98c379"
ONEDARK_YELLOW = "#e5c07b"
ONEDARK_BLUE = "#61afef"
ONEDARK_CYAN = "#56b6c2"
ONEDARK_ORANGE = "#d19a66"

ONEDARK_THEME = Theme(
    name="onedark",
    primary=ONEDARK_BLUE,
    secondary=ONEDARK_CYAN,
    warning=ONEDARK_YELLOW,
    error=ONEDARK_RED,
    success=ONEDARK_GREEN,
    accent=ONEDARK_ORANGE,
    foreground=ONEDARK_FOREGROUND,
    background=ONEDARK_BACKGROUND,
    surface=ONEDARK_SURFACE,
    panel=ONEDARK_SURFACE,
    dark=True,
)
