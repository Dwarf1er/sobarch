#!/bin/bash
# Adds another OS's bootloader (e.g. Windows) from a different ESP to the
# Limine menu. Interactive, so run manually after first boot. UEFI only.

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

ESP_PARTTYPE="c12a7328-f81f-11d2-ba4b-00a0c93ec93b"
own_esp="$(findmnt -no SOURCE /boot)"

scan_root="$(mktemp -d)"
cleanup() {
    for mnt in "$scan_root"/*/; do
        if [ -d "$mnt" ] && mountpoint -q "$mnt"; then umount "$mnt" || true; fi
    done
    # rmdir, never rm -rf: a mount that failed to unmount must not be recursed into.
    rmdir "$scan_root"/* "$scan_root" 2>/dev/null || true
}
trap cleanup EXIT

# One entry per candidate: "<partuuid>|<path on that ESP>"
candidates=()
n=0
while read -r dev parttype partuuid; do
    [ "${parttype,,}" = "$ESP_PARTTYPE" ] || continue
    [ "$dev" = "$own_esp" ] && continue
    [ -n "$partuuid" ] || continue
    n=$((n + 1))
    mnt="$scan_root/$n"
    mkdir -p "$mnt"
    mount -o ro "$dev" "$mnt" 2>/dev/null || continue
    while IFS= read -r path; do
        candidates+=("$partuuid|${path#"$mnt"}")
    done < <(find "$mnt" -iname "*.efi" -type f | sort)
done < <(lsblk -rnpo PATH,PARTTYPE,PARTUUID)

if [ "${#candidates[@]}" -eq 0 ]; then
    echo "limine-add-os-entry.sh: no other bootloader found on any other EFI System Partition." >&2
    exit 1
fi

echo "Other bootloaders found:"
for i in "${!candidates[@]}"; do
    printf '  %d) %s (partition %s)\n' "$((i + 1))" "${candidates[$i]#*|}" "${candidates[$i]%%|*}"
done

read -rp "Add which one to the Limine boot menu? [1-${#candidates[@]}]: " choice
if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#candidates[@]}" ]; then
    echo "limine-add-os-entry.sh: invalid choice." >&2
    exit 1
fi
chosen="${candidates[$((choice - 1))]}"
chosen_partuuid="${chosen%%|*}"
chosen_path="${chosen#*|}"

read -rp "Entry name to show in the boot menu [Windows]: " entry_name
entry_name="${entry_name:-Windows}"

# Per-entry markers so adding a second OS doesn't replace the first.
slug=$(echo "$entry_name" | tr -c 'A-Za-z0-9' '-' | tr -s '-' | sed 's/^-//;s/-$//' | tr '[:lower:]' '[:upper:]')
START_MARKER="#### SOBARCH OS ENTRY START ($slug, added by limine-add-os-entry.sh) ####"
END_MARKER="#### SOBARCH OS ENTRY END ($slug) ####"

block="$START_MARKER
/$entry_name
    protocol: efi
    path: guid(${chosen_partuuid}):${chosen_path}
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
