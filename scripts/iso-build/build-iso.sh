#!/usr/bin/env bash
# Builds the sobarch ISO from a fresh copy of Arch's releng profile plus
# the installer.
#
# Usage: build-iso.sh REPO_DIR OUTPUT_DIR
#
# Needs root in a privileged container (loop devices for mkarchiso).

set -euo pipefail
shopt -s inherit_errexit

if (($# != 2)); then
    echo "usage: $0 REPO_DIR OUTPUT_DIR" >&2
    exit 1
fi

REPO_DIR="$(cd "$1" && pwd)"
OUTPUT_DIR="$2"
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"

# releng's profiledef.sh honors SOURCE_DATE_EPOCH; sharing it keeps the
# ISO's internal version and the release filename on the same date.
SOURCE_DATE_EPOCH="$(date -u +%s)"
export SOURCE_DATE_EPOCH

pacman -Sy --noconfirm --needed archiso git

WORK_DIR="$(mktemp -d /var/tmp/sobarch-iso-build.XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

# The releng profile ships inside the archiso repo at configs/releng/.
echo "build-iso: fetching archiso profile source"
git clone --depth 1 https://gitlab.archlinux.org/archlinux/archiso.git "$WORK_DIR/archiso"
PROFILE="$WORK_DIR/archiso/configs/releng"

# User-visible "Arch Linux" strings are static text in each file. The
# internal install_dir "arch" is left alone.
echo "build-iso: rebranding boot text (Arch Linux -> Sobarch)"
sed -i \
    -e 's/iso_name="archlinux"/iso_name="sobarch"/' \
    -e 's/iso_label="ARCH_/iso_label="SOBARCH_/' \
    -e 's#iso_publisher="Arch Linux <https://archlinux.org>"#iso_publisher="Sobarch <https://github.com/Dwarf1er/sobarch>"#' \
    -e 's/iso_application="Arch Linux Live\/Rescue DVD"/iso_application="Sobarch Installer"/' \
    "$PROFILE/profiledef.sh"

sed -i 's/MENU TITLE Arch Linux/MENU TITLE Sobarch/' "$PROFILE/syslinux/archiso_head.cfg"

sed -i \
    -e 's/Arch Linux install medium/Sobarch installer/g' \
    -e 's/It allows you to install Arch Linux/It allows you to install Sobarch/g' \
    "$PROFILE/syslinux/archiso_sys-linux.cfg"

sed -i 's/title    Arch Linux install medium/title    Sobarch installer/' \
    "$PROFILE/efiboot/loader/entries/01-archiso-linux.conf" \
    "$PROFILE/efiboot/loader/entries/02-archiso-speech-linux.conf"

echo "sobarch" > "$PROFILE/airootfs/etc/hostname"

# Copy the whole tree since the installer reaches several paths by
# relative position; only project-meta content and build litter are excluded.
echo "build-iso: layering sobarch checkout into airootfs"
mkdir -p "$PROFILE/airootfs/root/sobarch"
rsync -a \
    --exclude='.git' \
    --exclude='.github' \
    --exclude='.githooks' \
    --exclude='website' \
    --exclude='docs' \
    --exclude='pkg' \
    --exclude='src' \
    --exclude='*.pkg.tar.*' \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    "$REPO_DIR/" "$PROFILE/airootfs/root/sobarch/"

echo "build-iso: adding python/python-textual to the profile package list"
{
    echo "python"
    echo "python-textual"
} >> "$PROFILE/packages.x86_64"

# releng's root autologin runs ~/.automated_script.sh. TODO: confirm this
# still holds for current releng. The script= handling is copied from
# releng's own script so PXE unattended installs keep working; the TUI
# launches only when no script= was given.
echo "build-iso: wiring auto-launch of the installer TUI (with a script= PXE override)"
cat > "$PROFILE/airootfs/root/.automated_script.sh" <<'SCRIPT'
#!/usr/bin/env bash

script_cmdline() {
    local param
    for param in $(</proc/cmdline); do
        case "${param}" in
            script=*)
                echo "${param#*=}"
                return 0
                ;;
        esac
    done
}

automated_script() {
    local script rt
    script="$(script_cmdline)"
    if [[ -n "${script}" && ! -x /tmp/startup_script ]]; then
        if [[ "${script}" =~ ^((http|https|ftp|tftp)://) ]]; then
            printf '%s: downloading %s\n' "$0" "${script}"
            systemd-run --pty --quiet -p Wants=network-online.target -p After=network-online.target \
                curl "${script}" --location --retry-connrefused --retry 10 --fail -s -o /tmp/startup_script
            rt=$?
        else
            cp "${script}" /tmp/startup_script
            rt=$?
        fi
        if [[ ${rt} -eq 0 ]]; then
            chmod +x /tmp/startup_script
            printf '%s: executing automated script\n' "$0"
            /tmp/startup_script
        fi
    fi
}

if [[ $(tty) == "/dev/tty1" ]]; then
    if [[ -n "$(script_cmdline)" ]]; then
        automated_script
    else
        python3 /root/sobarch/installer/tui/__main__.py < /dev/tty
    fi
fi
SCRIPT
chmod +x "$PROFILE/airootfs/root/.automated_script.sh"

echo "build-iso: running mkarchiso"
mkarchiso -v -w "$WORK_DIR/mkarchiso-work" -o "$WORK_DIR/out" "$PROFILE"

built_iso="$(find "$WORK_DIR/out" -maxdepth 1 -name '*.iso' | head -1)"
if [[ -z "$built_iso" ]]; then
    echo "build-iso: mkarchiso produced no .iso" >&2
    exit 1
fi

iso_name="sobarch-$(date -u --date="@$SOURCE_DATE_EPOCH" +%Y.%m.%d)-x86_64.iso"
cp "$built_iso" "$OUTPUT_DIR/$iso_name"

# GitHub rejects release assets over 2GiB.
iso_size="$(stat -c%s "$OUTPUT_DIR/$iso_name")"
iso_size_mib=$((iso_size / 1024 / 1024))
echo "build-iso: wrote $OUTPUT_DIR/$iso_name ($iso_size_mib MiB)"
if ((iso_size > 2 * 1024 * 1024 * 1024)); then
    echo "build-iso: WARNING -- ISO is ${iso_size_mib} MiB, over GitHub's 2GiB release-asset limit" >&2
elif ((iso_size > 1800 * 1024 * 1024)); then
    echo "build-iso: WARNING -- ISO is ${iso_size_mib} MiB, close to GitHub's 2GiB release-asset limit" >&2
fi
