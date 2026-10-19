#!/usr/bin/env bash
# Builds ks-aur-scanner's aur-scan binary into DEST. Upstream ships no
# prebuilt binaries. The pinned version is in aur-scan.version.

set -euo pipefail
shopt -s inherit_errexit

dest="${1:?usage: build-aur-scan.sh DEST}"
ref="$(<"$(dirname "${BASH_SOURCE[0]}")/aur-scan.version")"

clone_dir="$(mktemp -d)"
trap 'rm -rf "$clone_dir"' EXIT

git clone --depth 1 --branch "$ref" \
    https://github.com/KiefStudioMA/ks-aur-scanner.git "$clone_dir"
(cd "$clone_dir" && cargo build --release --locked -p aur-scanner-cli)
install -Dm755 "$clone_dir/target/release/aur-scan" "$dest"
"$dest" --version
