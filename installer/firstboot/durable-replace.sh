#!/usr/bin/env bash
# Sourced by apply-skel.sh and update-config-menu.sh, never run
# directly: replaces a file the way `install -Dm"$mode" src dest` does,
# but crash-safely.
#
# `install`/`cp` swap an existing destination via a fresh inode and a
# rename (confirmed directly: the destination's inode number changes
# across a run), with no fsync of their own. A real run hit this gap
# for real: the desktop froze mid config-update, was force shut down,
# and every file the reconciliation loop had already touched came back
# zero-length on reboot -- the classic "the rename committed to the
# journal before the new file's data was flushed" crash window, made
# worse by looping over dozens of files with nothing durable in
# between any of them.
#
# durable_replace fixes the ordering: write the new content to a temp
# file in the SAME directory as the destination (so the final rename
# stays on one filesystem and is atomic), fsync that file's data,
# rename it into place, then fsync the directory so the rename itself
# is durable too. A crash at any point now leaves either the old file
# or the fully-written new one, never a truncated one.
durable_replace() {
    local mode="$1" src="$2" dest="$3" dir tmp
    dir="$(dirname "$dest")"
    mkdir -p "$dir"
    tmp="$(mktemp "$dir/.sobarch-tmp.XXXXXX")"
    cp -- "$src" "$tmp"
    chmod "$mode" "$tmp"
    sync -- "$tmp"
    mv -f -- "$tmp" "$dest"
    sync -- "$dir"
}
