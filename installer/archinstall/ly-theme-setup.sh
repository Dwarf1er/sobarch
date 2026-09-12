#!/bin/bash
# ly greeter theming: colormix animation, big clock, OneDark accent on
# the input border, matching the rest of the session's visual pass.
#
# UNVERIFIED: authored from ly's documented config.ini keys, not
# confirmed against a real greeter session (no display/TTY in this
# sandbox). Unlike limine-theme-setup.sh, this is low-risk to get
# wrong: ly ignores unrecognized keys rather than failing to start,
# and a bad value here degrades the login screen's look, not the
# machine's ability to boot to a TTY. Sanity-check by watching the
# first real login screen and adjusting values directly in
# /etc/ly/config.ini if anything looks off.

set -euo pipefail

mkdir -p /etc/ly
cat > /etc/ly/config.ini <<'EOF'
animation = colormix
min_refresh_delta = 5
bigclock = en
clock = %a %d %b  %H:%M
blank_password = false
hide_borders = false
border_fg = 4
bg = 0
fg = 7
EOF

echo "ly-theme-setup.sh: done (unverified -- check the greeter on first reboot)."
