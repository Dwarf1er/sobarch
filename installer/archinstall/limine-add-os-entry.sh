#!/bin/bash
# Adds another OS's UEFI bootloader (e.g. Windows) to the Limine boot
# menu, for a free-space (dual-boot) install where sobarch's /boot IS
# the shared EFI System Partition (ESP) -- see docs/DECISIONS.md and
# website/content/docs/installer/dual-boot.md. Interactive by design
# (asks which detected .efi application to add), so this is a manual,
# post-first-boot command (`sudo limine-add-os-entry.sh`), never run
# from the scripted installer pipeline (install_runner.py's chroot
# steps have no TTY to prompt on).
#
# Scans the shared ESP's filesystem for *.efi applications rather than
# parsing efibootmgr's NVRAM boot-entry device-path binary format:
# sobarch's own Limine binaries and the other OS's bootloader both live
# as plain files on the same mounted /boot, so a filesystem scan finds
# exactly what a Limine `boot():/path` chainload entry needs (see
# limine-theme-setup.sh's own use of that same boot():/path syntax),
# with far less to get wrong in bash than decoding NVRAM device paths.
# This also means no efibootmgr dependency.
#
# UEFI-only, matching disk_probe.py's own scope cut (free-space
# installs are never offered on a BIOS/MBR disk), so unlike its
# siblings this script has no BIOS-mode limine.conf path branch.

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "limine-add-os-entry.sh: must be run as root (sudo)." >&2
    exit 1
fi

if [ ! -d /sys/firmware/efi ]; then
    echo "limine-add-os-entry.sh: this machine isn't booted in UEFI mode; nothing to do." >&2
    exit 1
fi

LIMINE_CONF="/boot/EFI/BOOT/limine.conf"

# sobarch's own Limine binaries (archinstall's _add_limine_bootloader()
# with bootloader_config.removable: true writes here), never offered as
# something to chainload into.
OWN_EFI_PATHS=(
    "/boot/EFI/BOOT/BOOTX64.EFI"
    "/boot/EFI/BOOT/BOOTIA32.EFI"
)

candidates=()
while IFS= read -r path; do
    is_own=false
    for own in "${OWN_EFI_PATHS[@]}"; do
        [ "$path" = "$own" ] && is_own=true
    done
    "$is_own" || candidates+=("$path")
done < <(find /boot -iname "*.efi" -type f | sort)

if [ "${#candidates[@]}" -eq 0 ]; then
    echo "limine-add-os-entry.sh: no other bootloader found on /boot." >&2
    exit 1
fi

echo "Other bootloaders found on /boot:"
for i in "${!candidates[@]}"; do
    printf '  %d) %s\n' "$((i + 1))" "${candidates[$i]}"
done

read -rp "Add which one to the Limine boot menu? [1-${#candidates[@]}]: " choice
if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#candidates[@]}" ]; then
    echo "limine-add-os-entry.sh: invalid choice." >&2
    exit 1
fi
chosen_path="${candidates[$((choice - 1))]}"

read -rp "Entry name to show in the boot menu [Windows]: " entry_name
entry_name="${entry_name:-Windows}"

# boot():/path is relative to the partition Limine itself was loaded
# from -- our shared ESP -- so stripping the /boot mountpoint prefix
# from the absolute path gives exactly what that syntax expects.
relative_path="${chosen_path#/boot}"

# Slugged from the entry name, not a single fixed marker like
# limine-theme-setup.sh/rescue-iso-setup.sh use: re-running this for a
# second OS (or a different pick) adds its own block instead of
# clobbering a previous one.
slug=$(echo "$entry_name" | tr -c 'A-Za-z0-9' '-' | tr -s '-' | sed 's/^-//;s/-$//' | tr '[:lower:]' '[:upper:]')
START_MARKER="#### SOBARCH OS ENTRY START ($slug, added by limine-add-os-entry.sh) ####"
END_MARKER="#### SOBARCH OS ENTRY END ($slug) ####"

block="$START_MARKER
/$entry_name
    protocol: efi
    path: boot():${relative_path}
$END_MARKER"

if grep -qF "$START_MARKER" "$LIMINE_CONF"; then
    awk -v start="$START_MARKER" -v end="$END_MARKER" -v block="$block" '
        $0 == start { print block; skipping = 1; next }
        $0 == end && skipping { skipping = 0; next }
        skipping { next }
        { print }
    ' "$LIMINE_CONF" > "${LIMINE_CONF}.sobarch-new"
    mv "${LIMINE_CONF}.sobarch-new" "$LIMINE_CONF"
else
    printf '\n%s\n' "$block" >> "$LIMINE_CONF"
fi

echo "limine-add-os-entry.sh: added \"$entry_name\" to the Limine boot menu."
