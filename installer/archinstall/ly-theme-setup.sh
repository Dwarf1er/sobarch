#!/bin/bash
# ly greeter theming: the actual installed `ly` package (confirmed
# 1.4.1-1 against a real test machine's `pacman -Qi ly`) configures
# itself via /etc/ly/config.ini, not config.lua. An earlier version of
# this script targeted config.lua, on the assumption that ly 1.4.1+
# had switched to a Lua-scripted config the way fairyglade/ly's GitHub
# master branch has (its src/animations/Lua.zig, confirmed against that
# upstream source). That assumption was wrong for this package build:
# `pacman -Ql ly` on the test machine shows only config.ini/
# config.ini.example, no config.lua or example.lua anywhere, and
# `ldd /usr/bin/ly-dm | grep -i lua` finds no Lua library linked in at
# all. Whatever version of ly eventually ships that feature, it isn't
# this one, so config.lua was silently doing nothing the entire time
# this script wrote it -- caught because a rebooted test machine kept
# showing ly's own stock colormix+bigclock look (the actual compiled-in
# defaults) instead of any sobarch branding at all.
#
# Runs twice in this script's lifetime, unmodified either time: once
# raw-copied into the target and run inside arch-chroot at install time
# (install_runner.py's CHROOT_SETUP_SCRIPTS), and later, packaged as
# /usr/local/lib/sobarch/ly-theme-setup.sh by sobarch-scripts, re-run by
# update-config-menu.sh (via pkexec) whenever sobarch-skel refreshes so
# an already-installed system picks up branding changes too. Nothing
# here depends on being inside a fresh chroot specifically (no
# archinstall-only env vars), and every write below already overwrites
# unconditionally, so no separate "refresh" variant was needed. A
# config.ini/sobarch-logo.dur rewrite only takes effect the next time ly
# itself starts (reboot, or `systemctl restart ly@tty1` -- the unit is
# templated per-tty, confirmed against the test machine's own
# `pacman -Ql ly`, not a plain `ly.service`); this script doesn't force
# that.
#
# The centerpiece is the sobarch mark played back via ly's built-in
# `dur_file` animation type (config.ini's `animation` key has a fixed
# enum: none/doom/matrix/colormix/gameoflife/dur_file -- confirmed
# against the test machine's own /etc/ly/config.ini.example -- there is
# no way to point it at a custom script or a plain static image; a
# single-frame .dur "movie" is the only way to get a static custom
# mark out of ly at all). The .dur file itself
# (branding/sobarch-logo.dur) is a prebuilt gzip-compressed JSON asset,
# not generated here.
#
# Real-machine testing (2026-09-15) confirmed the dur_file mechanism
# itself does render (gzip+JSON parsing, sizing, glyph placement all
# correct) but showed the mark in plain white, not colored, and
# animated (reveal/disperse) rather than static -- both from this
# file's first version, built before ly's actual color-index remap was
# read from source. Fixed by reading fairyglade/ly's real upstream
# source directly this time (DurFile.zig, TerminalBuffer.zig), not
# copying an index pair from ly's own res/example.dur and hoping:
#   - The old file used colorFormat 16 with fg/bg index 8 on every
#     glyph cell. DurFile.zig's `draw()` remaps a 16-format index
#     through `durcolor_table_to_color16` before use -- fg index 8
#     remaps to 7, bg index 8 remaps (via its own `+1` offset quirk,
#     confirmed in source, not guessed) to 8. With `full_color = true`
#     (ly's own documented default, now also set explicitly below),
#     those feed into `convert256ToRgb`, landing on
#     `rgb_color_16[7]` = `TRUE_DIM_WHITE` (0xC0C0C0) for the glyph and
#     `rgb_color_16[8]` = `Color.DEFAULT | BOLD` (transparent) for the
#     background -- exactly the plain-white-on-transparent look
#     reported.
#   - The new file uses colorFormat 256 instead, which skips that
#     16-color remap entirely (confirmed in source: the remap only
#     runs `if (self.is_color_format_16)`) and passes the raw index
#     straight into the same `convert256ToRgb`. Glyph cells use index
#     75 (`sixCubeToChannel(1,3,5)` = 0x5FAFFF), the closest color in
#     xterm-256's 6x6x6 cube to the OneDark accent used everywhere else
#     in this session (0x61afef; off by 2/0/16 per channel out of
#     255 -- not exact, cube-quantized colors can't be), and background
#     cells use index 0, which resolves to `Color.DEFAULT` (confirmed:
#     `rgb_color_16[0]`), the same transparent behavior as before so it
#     still blends with `bg` below rather than painting a mismatched
#     box.
#   - colorFormat 256 requires `full_color = true` or ly refuses to
#     draw the dur_file at all (config.ini.example's own documented
#     warning) -- previously only true by relying on that being ly's
#     compiled-in default when the key was omitted; now set explicitly
#     below so this doesn't silently break if that default ever
#     changes upstream.
#   - The file was also collapsed from 43 frames (a reveal/disperse
#     animation) down to 1 (the fully-revealed content only): DurFile's
#     own frame-advance logic (`(self.frames + 1) % frame_count`)
#     degenerates to redrawing the same single frame forever when
#     frame_count is 1, confirmed directly in source, so this needed no
#     config.ini change to stop animating.
# If the mark in branding/sobarch-logo-ascii.txt ever changes,
# sobarch-logo.dur has to be regenerated by hand to match (same
# colorFormat/index scheme above); see sobarch-skel's PKGBUILD comment
# on it.
#
# UNVERIFIED: the dur_file mechanism itself is now confirmed working on
# real hardware (above), but this specific fix -- the exact color, and
# the switch to a single static frame -- has not been watched rendering
# yet, same sandbox limitation as before (no display/TTY here).
# Sanity-check on the next real login screen; if the mark is still
# wrong, the four points above are exactly what to re-check first,
# since each was confirmed against real source this time rather than
# copied from a working reference.

set -euo pipefail

LOGO_SRC="/usr/share/sobarch/branding/sobarch-logo.dur"
LOGO_DUR="/etc/ly/sobarch-logo.dur"

mkdir -p /etc/ly

cp -f "$LOGO_SRC" "$LOGO_DUR"

# Leftovers from this script's earlier config.lua-based version: ly
# never reads them (confirmed above), but a stale config.lua sitting
# next to config.ini is a red herring for whoever debugs this next.
rm -f /etc/ly/config.lua /etc/ly/sobarch-logo.lua

# OneDark, same values used across Limine (limine-theme-setup.sh's own
# interface_branding_color/term_palette), Waybar, mako, fuzzel and
# hyprlock. config.ini's color fields use the same 0xSSRRGGBB truecolor
# format config.lua did (confirmed identical against the test machine's
# own config.ini.example header comment), so these carry over unchanged.
cat > /etc/ly/config.ini <<EOF
allow_empty_password = false
animation = dur_file
# animation_frame_delay left at its own default (5ms): sobarch-logo.dur
# is now a single static frame (see the header comment above), so this
# only governs how often DurFile redraws an unchanging frame; harmless
# either way, not worth tuning.
dur_file_path = $LOGO_DUR
dur_offset_alignment = center
# Required for sobarch-logo.dur's colorFormat 256 to render at all
# (ly's own documented behavior: a 256-format dur file is silently not
# drawn with this off). This happens to already be ly's own compiled-in
# default, but is set explicitly rather than relied on, since that's
# exactly the kind of undocumented-default assumption that already
# caused this file's original color bug.
full_color = true
bigclock = none
clock = %a %d %b  %H:%M
bg = 0x00282c34
fg = 0x00abb2bf
border_fg = 0x0061afef
hide_borders = false
EOF

echo "ly-theme-setup.sh: done (unverified, check the greeter on first reboot)."
