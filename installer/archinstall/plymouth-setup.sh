#!/bin/bash
# Installs sobarch's own Plymouth theme over the placeholder theme
# archinstall itself already selected during the `--silent` run
# (base.json's `bootloader_config.plymouth: "spinner"`).
#
# archinstall 4.4's own `Installer._install_plymouth()` (confirmed by
# reading its actual installed source directly, not assumed) already
# did the fiddly, easy-to-get-wrong infrastructure work as part of that
# same run, entirely from that one JSON field: installed the
# `plymouth` package, appended `quiet`/`splash` to the kernel
# parameters that feed every bootloader's generated entry (Limine's
# own `cmdline:` line included -- this is deliberately not hand-patched
# here the way limine-theme-setup.sh's own header comment explicitly
# avoids doing for entry-specific keys), inserted the `plymouth` hook
# into HOOKS at a safe position, and ran an initial
# `plymouth-set-default-theme`/`mkinitcpio -P`. `PlymouthTheme` is a
# fixed enum of 10 stock theme names bundled with the package itself,
# so archinstall's config can only select a placeholder, never a
# custom theme name -- this script's only job is swapping that
# placeholder for the real one and rebuilding the initramfs again.
#
# Runs twice in this script's lifetime, unmodified either time: once
# raw-copied into the target and run inside arch-chroot at install time
# (install_runner.py's CHROOT_SETUP_SCRIPTS, right after
# limine-theme-setup.sh), and later, packaged as
# /usr/local/lib/sobarch/plymouth-setup.sh by sobarch-scripts, re-run
# by update-config-menu.sh whenever sobarch-skel refreshes so an
# already-installed system picks up branding changes too. Nothing here
# depends on being inside a fresh chroot specifically (no
# archinstall-only env vars), and every write below already overwrites
# unconditionally, so no separate "refresh" variant was needed.
#
# UNVERIFIED: no display/TTY in this sandbox to confirm the splash
# actually renders, even with archinstall's own mechanism and the
# `-R` rebuild-on-theme-change flag both confirmed against real source/
# the Arch Wiki. See sobarch.script's own header comment for the two
# specific things most likely to be wrong if it doesn't. Sanity-check
# by watching the next real reboot.

set -euo pipefail

THEME_NAME="sobarch"
THEME_DIR="/usr/share/plymouth/themes/$THEME_NAME"
ASSET_DIR="/usr/share/sobarch/branding/plymouth-sobarch"

mkdir -p "$THEME_DIR"
cp -f "$ASSET_DIR/sobarch.plymouth" "$THEME_DIR/sobarch.plymouth"
cp -f "$ASSET_DIR/sobarch.script" "$THEME_DIR/sobarch.script"
# Same asset ly-theme-setup.sh/limine-theme-setup.sh already read from
# this package payload (see limine-theme-setup.sh's own comment on
# why: this runs inside arch-chroot before the target user's $HOME
# exists, so none of these three scripts can read from a
# skel-deployed path instead).
cp -f "/usr/share/sobarch/branding/sobarch-logo.png" "$THEME_DIR/sobarch-logo.png"

# -R rebuilds the initramfs itself (Arch Wiki, confirmed), superseding
# whichever placeholder theme archinstall's own _install_plymouth()
# selected earlier in this same install run.
plymouth-set-default-theme -R "$THEME_NAME"

echo "plymouth-setup.sh: done (unverified, check the splash on next reboot)."
