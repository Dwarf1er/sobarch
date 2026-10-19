#!/bin/bash
# Replaces the placeholder Plymouth theme archinstall selected with sobarch's own.
# archinstall already installed plymouth, set quiet/splash and added the hook;
# its config can only name a stock theme. Also re-run by update-system.sh.

set -euo pipefail

THEME_NAME="sobarch"
THEME_DIR="/usr/share/plymouth/themes/$THEME_NAME"
ASSET_DIR="/usr/share/sobarch/branding/plymouth-sobarch"

mkdir -p "$THEME_DIR"
cp -f "$ASSET_DIR/sobarch.plymouth" "$THEME_DIR/sobarch.plymouth"
cp -f "$ASSET_DIR/sobarch.script" "$THEME_DIR/sobarch.script"
cp -f "/usr/share/sobarch/branding/sobarch-logo.png" "$THEME_DIR/sobarch-logo.png"

# -R also rebuilds the initramfs.
plymouth-set-default-theme -R "$THEME_NAME"

echo "plymouth-setup.sh: done (unverified, check the splash on next reboot)."
