#!/usr/bin/env bash
# Entry point for `curl -fsSL <raw-url-to-this-file> | bash` on a stock
# Arch ISO: fetches the whole repo and launches the TUI. The installer
# needs packages/custom/ and skel/ too, not just installer/.

set -euo pipefail

REPO="Dwarf1er/sobarch"
BRANCH="master"
ARCHIVE_URL="https://github.com/${REPO}/archive/refs/heads/${BRANCH}.tar.gz"

WORKDIR="$(mktemp -d /tmp/sobarch-installer.XXXXXX)"
# Not exec'd: the checkout must stay on disk until the TUI exits.
trap 'rm -rf "$WORKDIR"' EXIT

echo "sobarch: fetching installer from ${REPO}@${BRANCH}..."
curl -fsSL "$ARCHIVE_URL" | tar -xz -C "$WORKDIR" --strip-components=1

echo "sobarch: launching installer..."
# stdin is curl's pipe, so the TUI must read keys from the tty.
python3 "$WORKDIR/installer/tui/__main__.py" "$@" < /dev/tty

