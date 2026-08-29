#!/bin/bash
# One-time hardware detection, run by the TUI before generating
# the archinstall JSON config from base.json. This is
# not an ongoing runtime service: it runs once, at install time.
#
# Prints shell variable assignments to stdout. The caller sources or
# evals the output, then uses it to fill in base.json's placeholder
# tokens (extra packages appended to the "packages" array,
# __BLUETOOTH_DETECTED__ substituted with true/false).
#
# AMD and Intel are fully supported. NVIDIA is best-effort only
# as I do not own any NVIDIA hardware to verify this path
# against, and this script does not attempt to distinguish NVIDIA GPU
# generations beyond the three tiers below.
#
# The NVIDIA generation split (device ID thresholds) matches Omarchy's
# own detection (bin/omarchy-hw-nvidia-gsp / omarchy-hw-nvidia-without-gsp:
# 0x1e00 for Turing/GSP, 0x1340 for Maxwell) and CachyOS's chwd
# (profiles/pci/graphic_drivers/profiles.toml; ids/nvidia-580.ids spans
# exactly 0x1340-0x1df6). Package lists (nvidia-settings, opencl-nvidia,
# lib32-vulkan-icd-loader, the mkinitcpio "kms" hook removal for
# proprietary driver tiers below) follow CachyOS's fuller reference.
# Hybrid-laptop-specific handling (PRIME/switcheroo-control,
# chassis-type detection, an NVIDIA RTD3 power-management workaround)
# is deliberately not included here: real value, but laptop-specific
# scope beyond GPU-generation detection.

set -euo pipefail

cpu_vendor=$(awk -F': ' '/^vendor_id/{print $2; exit}' /proc/cpuinfo)

case "$cpu_vendor" in
    GenuineIntel) CPU_MICROCODE_PKG="intel-ucode" ;;
    AuthenticAMD) CPU_MICROCODE_PKG="amd-ucode" ;;
    *)            CPU_MICROCODE_PKG="" ;;
esac

gpu_vendors=""
gpu_packages=""
nvidia_present=false
nvidia_proprietary_driver=false

while IFS= read -r -d '' card; do
    vendor_file="$card/device/vendor"
    [ -r "$vendor_file" ] || continue
    vendor_id=$(cat "$vendor_file")

    case "$vendor_id" in
        0x1002) # AMD
            gpu_vendors="$gpu_vendors amd"
            gpu_packages="$gpu_packages vulkan-radeon lib32-vulkan-radeon"
            ;;
        0x8086) # Intel
            gpu_vendors="$gpu_vendors intel"
            gpu_packages="$gpu_packages vulkan-intel lib32-vulkan-intel"
            ;;
        0x10de) # NVIDIA
            gpu_vendors="$gpu_vendors nvidia"
            nvidia_present=true

            device_id=$(cat "$card/device/device" 2>/dev/null || echo "0x0")

            if (( device_id >= 0x1e00 )); then
                # Turing (RTX 20xx) and newer: GSP-firmware capable,
                # mandatory for RTX 50xx (no proprietary driver path at
                # all for it otherwise).
                gpu_packages="$gpu_packages nvidia-open-dkms nvidia-utils lib32-nvidia-utils egl-wayland libva-nvidia-driver nvidia-settings opencl-nvidia lib32-opencl-nvidia lib32-vulkan-icd-loader"
                nvidia_proprietary_driver=true
            elif (( device_id >= 0x1340 )); then
                # Maxwell/Pascal/Volta: no GSP firmware. Needs the
                # pinned legacy 580xx driver branch specifically, plain
                # nvidia-dkms dropped support for this generation as of
                # driver 590.
                gpu_packages="$gpu_packages nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils egl-wayland libva-nvidia-driver nvidia-580xx-settings opencl-nvidia-580xx lib32-opencl-nvidia-580xx lib32-vulkan-icd-loader"
                nvidia_proprietary_driver=true
            else
                # Kepler and older: no proprietary driver family
                # packaged for this generation. Falls back to nouveau
                # (open-source), which needs no extra driver package
                # itself (already covered by the mesa/lib32-mesa
                # packages installed unconditionally) on this pure-
                # Wayland stack, just its firmware blobs and Mesa's
                # OpenCL support. Not a bail-out: the card still ends
                # up with a working, if less performant, driver.
                gpu_packages="$gpu_packages nouveau-fw opencl-mesa lib32-opencl-mesa"
            fi
            ;;
    esac
done < <(find /sys/class/drm -maxdepth 1 -name 'card[0-9]*' ! -name '*-*' -print0 2>/dev/null)

gpu_vendors=$(echo "$gpu_vendors" | xargs -n1 2>/dev/null | sort -u | xargs || true)
gpu_packages=$(echo "$gpu_packages" | xargs -n1 2>/dev/null | sort -u | xargs || true)

if [ -n "$(ls -A /sys/class/bluetooth/ 2>/dev/null)" ]; then
    bluetooth_detected=true
else
    bluetooth_detected=false
fi

cat <<EOF
CPU_MICROCODE_PKG="$CPU_MICROCODE_PKG"
GPU_VENDORS="$gpu_vendors"
GPU_PACKAGES="$gpu_packages"
NVIDIA_PRESENT=$nvidia_present
NVIDIA_PROPRIETARY_DRIVER=$nvidia_proprietary_driver
BLUETOOTH_DETECTED=$bluetooth_detected
EOF
