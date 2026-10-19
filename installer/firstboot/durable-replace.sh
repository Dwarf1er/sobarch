#!/usr/bin/env bash
# Sourced, not run. Crash-safe `install -Dm"$mode" src dest`: `install`/`cp`
# rename without fsync, so a crash can leave zero-length files. Write a temp
# file in the same directory, fsync it, rename, then fsync the directory.
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
