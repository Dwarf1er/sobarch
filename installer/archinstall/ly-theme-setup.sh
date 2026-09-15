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
# config.ini/sobarch-wordmark.dur rewrite only takes effect the next
# time ly itself starts (reboot, or `systemctl restart ly@tty1` -- the
# unit is templated per-tty, confirmed against the test machine's own
# `pacman -Ql ly`, not a plain `ly.service`); this script doesn't force
# that.
#
# The centerpiece is a "SOBARCH" wordmark (not the pictorial logo mark
# used at boot/lockscreen) played back via ly's built-in `dur_file`
# animation type (config.ini's `animation` key has a fixed enum:
# none/doom/matrix/colormix/gameoflife/dur_file -- confirmed against
# the test machine's own /etc/ly/config.ini.example -- there is no way
# to point it at a custom script or a plain static image; a
# single-frame .dur "movie" is the only way to get static custom
# content out of ly at all). Superseded the pictorial mark (real-machine
# testing, 2026-09-15): once actually visible on the greeter, that mark
# (40x21 cells) turned out taller than the console's actual clear space
# above ly's login box (only 18 rows, confirmed on the test machine;
# ly's box position is hardcoded dead-center on both axes in this
# version, no config exists to move it -- see below), an unavoidable
# few rows of overlap at any vertical placement. The wordmark
# (branding/sobarch-wordmark-ascii.txt, `branding/sobarch-wordmark.dur`
# built from it) is only 7 rows tall, comfortably inside that budget
# with room to spare, sidestepping the problem instead of fighting it.
# It reads "SOBARCH" with the initial S replaced by the Hangul
# consonant "siot" (ㅅ, U+3145) for a stylized mark, rendered via an
# actual bold typeface (Noto Sans Black for the Latin letters, Noto
# Sans CJK KR Black for ㅅ, height-matched by trimming each glyph to
# its true ink bounds first -- the CJK font's own reported bounding box
# included ~24px of invisible padding below the glyph, which is what
# made a first attempt render ㅅ visibly shorter than the rest) and
# downsampled to terminal cells using upper/lower half-block characters
# (▄▀█) for 2x the vertical resolution of a plain character-per-cell
# rendering, the same technique real terminal image viewers use. Both
# files are prebuilt, not generated on the live ISO/target; regenerate
# by hand (same font-render + half-block-downsample approach, then the
# colorFormat/index scheme documented below) if the wordmark ever
# changes.
#
# ly's `dur_file` color handling (confirmed by reading fairyglade/ly's
# real upstream source directly -- DurFile.zig, TerminalBuffer.zig --
# not assumed, and cross-checked between its master branch and the
# actually-installed v1.4.1 tag specifically, since master has already
# drifted in places, e.g. a since-added configurable login-box position
# this installed version doesn't have):
#   - `colorFormat: "256"` (not "16") skips DurFile's fiddly 16-color
#     index remap entirely (confirmed in source: that remap only runs
#     `if (self.is_color_format_16)`) and passes the raw index straight
#     into `convert256ToRgb`. Glyph cells use index 75
#     (`sixCubeToChannel(1,3,5)` = 0x5FAFFF), the closest color in
#     xterm-256's 6x6x6 cube to the OneDark accent used everywhere else
#     in this session (0x61afef; off by 2/0/16 per channel out of 255 --
#     not exact, cube-quantized colors can't be closer). Background
#     cells use index 0, which resolves to `Color.DEFAULT` (confirmed:
#     `rgb_color_16[0]`), i.e. transparent, so it blends with `bg`
#     below rather than painting a solid box.
#   - `colorFormat: "256"` requires `full_color = true` below or ly
#     silently refuses to draw the dur_file at all
#     (config.ini.example's own documented warning). This happens to
#     already be ly's compiled-in default, but is set explicitly rather
#     than relied on: an earlier version of this file's pictorial-mark
#     predecessor used the default 16-color remap instead (a leftover
#     from copying an index pair out of ly's own res/example.dur rather
#     than reading the remap logic itself) and rendered in plain white
#     as a direct result -- exactly the kind of undocumented-default
#     assumption worth not repeating.
#   - A .dur "movie" is collapsed to a single frame for static content:
#     DurFile's own frame-advance logic (`(self.frames + 1) %
#     frame_count`) degenerates to redrawing the same frame forever
#     when `frame_count` is 1, confirmed directly in source, so no
#     config.ini setting is needed to stop it animating.
#
# UNVERIFIED: the dur_file mechanism itself, colorFormat 256, and
# static single-frame playback are all confirmed working on real
# hardware (the pictorial mark's own fix, same mechanism this wordmark
# reuses unchanged). Not yet watched rendering, though: this specific
# wordmark content, and whether `topcenter` actually clears the login
# box by the comfortable margin expected (18 clear rows measured
# against a 7-row asset, versus the previous mark's 21-row asset
# against that same 18-row budget) -- no display/TTY in the sandbox
# this was authored in. Sanity-check on the next real login screen.

set -euo pipefail

WORDMARK_SRC="/usr/share/sobarch/branding/sobarch-wordmark.dur"
WORDMARK_DUR="/etc/ly/sobarch-wordmark.dur"

mkdir -p /etc/ly

cp -f "$WORDMARK_SRC" "$WORDMARK_DUR"

# Leftovers from this script's earlier config.lua-based version: ly
# never reads them (confirmed above), but a stale config.lua sitting
# next to config.ini is a red herring for whoever debugs this next.
rm -f /etc/ly/config.lua /etc/ly/sobarch-logo.lua
# Leftover from the pictorial-mark version this wordmark superseded.
rm -f /etc/ly/sobarch-logo.dur

# OneDark, same values used across Limine (limine-theme-setup.sh's own
# interface_branding_color/term_palette), Waybar, mako, fuzzel and
# hyprlock. config.ini's color fields use the same 0xSSRRGGBB truecolor
# format config.lua did (confirmed identical against the test machine's
# own config.ini.example header comment), so these carry over unchanged.
cat > /etc/ly/config.ini <<EOF
allow_empty_password = false
animation = dur_file
# animation_frame_delay left at its own default (5ms): sobarch-wordmark.dur
# is a single static frame (see the header comment above), so this only
# governs how often DurFile redraws an unchanging frame; harmless
# either way, not worth tuning.
dur_file_path = $WORDMARK_DUR
# topcenter: ly's login box (username/password/session fields) is
# hardcoded dead-center on screen in the actual installed version
# (confirmed against fairyglade/ly's real v1.4.1 tag, not its newer
# master branch, which adds a since-unreleased configurable
# box_position_v/h this version doesn't have -- state.box.positionXY in
# src/main.zig centers on both axes unconditionally, no config term
# feeds into it at all). The wordmark is only 7 rows tall against an
# 18-row clear budget above the box (measured on the real test
# machine), so topcenter has ample margin here, unlike the taller
# pictorial mark this superseded.
dur_offset_alignment = topcenter
# Required for sobarch-wordmark.dur's colorFormat 256 to render at all
# (ly's own documented behavior: a 256-format dur file is silently not
# drawn with this off). This happens to already be ly's own compiled-in
# default, but is set explicitly rather than relied on, since that's
# exactly the kind of undocumented-default assumption that caused this
# asset's pictorial-mark predecessor's original color bug.
full_color = true
bigclock = none
clock = %a %d %b  %H:%M
bg = 0x00282c34
fg = 0x00abb2bf
border_fg = 0x0061afef
hide_borders = false
EOF

echo "ly-theme-setup.sh: done (unverified, check the greeter on first reboot)."
