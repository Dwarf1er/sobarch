#!/usr/bin/env bash
# Sourced by rescue-iso-setup.sh (install-time, arch-chroot) and
# refresh-rescue-iso.sh (post-install, user-triggered via Sobarch ->
# Refresh Rescue ISO), never run directly: the one place that fetches
# and verifies a current Arch ISO and extracts the kernel/initramfs it
# boots from, so both call sites stay byte-for-byte the same logic
# instead of two copies drifting apart.

MIRROR_URL="https://geo.mirror.pkgbuild.com/iso/latest"

# Downloads archlinux-x86_64.iso plus its sha256sums.txt into WORK_DIR
# (caller-owned: create it and clean it up) and verifies the checksum.
fetch_rescue_iso() {
    local work_dir="$1"

    curl -fL -o "$work_dir/archlinux-x86_64.iso" "$MIRROR_URL/archlinux-x86_64.iso"
    curl -fL -o "$work_dir/sha256sums.txt" "$MIRROR_URL/sha256sums.txt"

    ( cd "$work_dir" && grep 'archlinux-x86_64\.iso$' sha256sums.txt | sha256sum -c - )
}

# Loop-mounts WORK_DIR/archlinux-x86_64.iso (fetch_rescue_iso must have
# already put it there) and copies out the kernel/initramfs it boots
# from, as WORK_DIR/vmlinuz-linux and WORK_DIR/initramfs-linux.img.
extract_rescue_kernel() {
    local work_dir="$1" loop_mnt="$1/iso-mount"

    mkdir -p "$loop_mnt"
    mount -o loop,ro "$work_dir/archlinux-x86_64.iso" "$loop_mnt"
    # Standard archiso layout (the same path the current Arch
    # installation medium itself boots from); worth re-confirming if a
    # future Arch release ever changes it.
    cp "$loop_mnt/arch/boot/x86_64/vmlinuz-linux" "$work_dir/vmlinuz-linux"
    cp "$loop_mnt/arch/boot/x86_64/initramfs-linux.img" "$work_dir/initramfs-linux.img"
    umount "$loop_mnt"
}
