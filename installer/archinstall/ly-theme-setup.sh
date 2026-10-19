#!/bin/bash
# ly greeter theming via /etc/ly/config.ini (this ly build has no Lua config).
# Takes effect the next time ly starts (reboot or systemctl restart ly@tty1).
#
# ly can only show custom static content as a single-frame dur_file animation.
# The wordmark .dur uses colorFormat 256 (index 75 is near OneDark 0x61afef,
# index 0 is transparent), which ly refuses to draw unless full_color = true.
# It is prebuilt from branding/sobarch-wordmark-ascii.txt.

set -euo pipefail

WORDMARK_SRC="/usr/share/sobarch/branding/sobarch-wordmark.dur"
WORDMARK_DUR="/etc/ly/sobarch-wordmark.dur"

mkdir -p /etc/ly

cp -f "$WORDMARK_SRC" "$WORDMARK_DUR"

# Stale files from older installs; ly never reads them.
rm -f /etc/ly/config.lua /etc/ly/sobarch-logo.lua
rm -f /etc/ly/sobarch-logo.dur

# OneDark colors in 0xSSRRGGBB format, matching Limine and the desktop.
cat > /etc/ly/config.ini <<EOF
allow_empty_password = false
animation = dur_file
dur_file_path = $WORDMARK_DUR
# ly 1.4 always centers the login box, so the wordmark goes above it.
dur_offset_alignment = topcenter
# Centers the 7-row wordmark in the space above the box.
dur_y_offset = 5
# A 256-color dur file isn't drawn at all without this.
full_color = true
bigclock = none
clock = %a %d %b  %H:%M
bg = 0x00282c34
fg = 0x00abb2bf
border_fg = 0x0061afef
hide_borders = false
EOF

echo "ly-theme-setup.sh: done (unverified, check the greeter on first reboot)."
