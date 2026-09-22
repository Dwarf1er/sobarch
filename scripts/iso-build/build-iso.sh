#!/usr/bin/env bash
# Builds the monthly sobarch ISO: Arch's own `releng` archiso profile,
# fetched fresh (never a persisted fork, so upstream releng/kernel drift
# is absorbed automatically), layered with this project's installer and
# the prebuilt package cache from build-package-cache.sh.
#
# Usage: build-iso.sh REPO_DIR CACHE_DIR OUTPUT_DIR
#   REPO_DIR    an existing checkout of this repo
#   CACHE_DIR   output dir from build-package-cache.sh
#   OUTPUT_DIR  where the finished .iso is written
#
# Must run inside a privileged container: mkarchiso needs loop devices
# and squashfs tooling, a real Arch userland, and root.

set -euo pipefail
shopt -s inherit_errexit

if (($# != 3)); then
    echo "usage: $0 REPO_DIR CACHE_DIR OUTPUT_DIR" >&2
    exit 1
fi

REPO_DIR="$(cd "$1" && pwd)"
CACHE_DIR="$(cd "$2" && pwd)"
OUTPUT_DIR="$3"
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"

pacman -Sy --noconfirm --needed archiso git

WORK_DIR="$(mktemp -d /var/tmp/sobarch-iso-build.XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "build-iso: fetching releng profile"
git clone --depth 1 https://gitlab.archlinux.org/archlinux/releng.git "$WORK_DIR/releng"
PROFILE="$WORK_DIR/releng"

# The full checkout, not a hand-picked subset: install_runner.py's own
# post-archinstall build step reaches several paths by relative position
# in the repo tree (packages/custom/sobarch-skel, packages/aur/<pkg> for
# each base-required AUR package, skel/, branding/, installer/firstboot/,
# scripts/aur-sync/ -- see install_runner.py's own staging list), the
# same shape bootstrap.sh's tarball fetch already gives at runtime.
# Copying the whole tree here means that relationship never needs to be
# re-enumerated or kept in sync by hand as install_runner.py evolves.
echo "build-iso: layering sobarch checkout into airootfs"
mkdir -p "$PROFILE/airootfs/root/sobarch"
rsync -a --exclude='.git' "$REPO_DIR/" "$PROFILE/airootfs/root/sobarch/"

echo "build-iso: layering package cache into airootfs"
mkdir -p "$PROFILE/airootfs/opt/sobarch-cache"
cp -a "$CACHE_DIR"/. "$PROFILE/airootfs/opt/sobarch-cache/"

echo "build-iso: adding python/python-textual to the profile package list"
{
    echo "python"
    echo "python-textual"
} >> "$PROFILE/packages.x86_64"

# archiso's default releng root shell auto-execs ~/.automated_script.sh
# on login if present -- TODO(first real CI run): confirm this is still
# how the current releng profile's root autologin works before relying
# on it; if it's changed, this needs a systemd getty@tty1 drop-in or
# equivalent instead.
echo "build-iso: wiring auto-launch of the installer TUI"
cat > "$PROFILE/airootfs/root/.automated_script.sh" <<'SCRIPT'
#!/usr/bin/env bash
python3 /root/sobarch/installer/tui/__main__.py < /dev/tty
SCRIPT
chmod +x "$PROFILE/airootfs/root/.automated_script.sh"

echo "build-iso: running mkarchiso"
mkarchiso -v -w "$WORK_DIR/mkarchiso-work" -o "$WORK_DIR/out" "$PROFILE"

built_iso="$(find "$WORK_DIR/out" -maxdepth 1 -name '*.iso' | head -1)"
if [[ -z "$built_iso" ]]; then
    echo "build-iso: mkarchiso produced no .iso" >&2
    exit 1
fi

iso_name="sobarch-$(date -u +%Y.%m.%d)-x86_64.iso"
cp "$built_iso" "$OUTPUT_DIR/$iso_name"
echo "build-iso: wrote $OUTPUT_DIR/$iso_name"
