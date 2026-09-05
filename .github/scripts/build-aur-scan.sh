#!/usr/bin/env bash
# Builds ks-aur-scanner's aur-scan binary from source into DEST.
# https://github.com/KiefStudioMA/ks-aur-scanner ships no prebuilt
# binary on any release (checked every tag), so this is the only way
# to get it. Shared by .github/workflows/aur.yml and checks.yml so the
# pinned version and build recipe live in exactly one place --
# aur-scan.version, next to this script -- instead of two workflow
# files drifting independently.
#
# Only builds the aur-scan binary (crate aur-scanner-cli), not the
# aur-scan-wrap/aur-scan-hook shell-integration binaries this repo has
# no use for.

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
