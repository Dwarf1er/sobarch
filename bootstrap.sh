#!/usr/bin/env bash
# The single command a stock Arch ISO shell runs to reach the sobarch
# TUI: `curl -fsSL <raw-url-to-this-file> | bash`. Does
# nothing but fetch a checkout of this repository and launch the TUI;
# no other setup, no custom ISO.
#
# Fetches the whole repository, not only installer/: install_runner.py
# also needs packages/custom/sobarch-skel and configs/skel from the
# same checkout to build/deploy sobarch-skel during install (see its
# REPO_ROOT). A plain curl+tar pull of GitHub's own archive endpoint
# gets all three in one step with no server of our own and no new
# dependency beyond curl/tar, both already required to run this script
# at all or present on every Arch install medium.
#
# python3/python-textual/archinstall are not installed here: they're
# already on the live ISO (archinstall itself depends on
# python-textual), so nothing on top of a stock Arch ISO is required.

set -euo pipefail

REPO="Dwarf1er/sobarch"
BRANCH="master"
ARCHIVE_URL="https://github.com/${REPO}/archive/refs/heads/${BRANCH}.tar.gz"

WORKDIR="$(mktemp -d /tmp/sobarch-installer.XXXXXX)"
# Not `exec`'d below: install_runner.py needs this checkout to still be
# on disk for the whole TUI session (it reads packages/custom/ and
# configs/ from it during a real install), so it can only be removed
# once the TUI itself has actually exited.
trap 'rm -rf "$WORKDIR"' EXIT

echo "sobarch: fetching installer from ${REPO}@${BRANCH}..."
curl -fsSL "$ARCHIVE_URL" | tar -xz -C "$WORKDIR" --strip-components=1

echo "sobarch: launching installer..."
# stdin here is still curl's pipe, not the terminal (this whole script
# runs as `curl | bash`), so the TUI must read keys from the tty
# directly or it can't enter raw mode: arrow keys/Enter would just get
# echoed by the terminal as literal escape sequences instead of being
# read as input.
python3 "$WORKDIR/installer/tui/__main__.py" "$@" < /dev/tty

