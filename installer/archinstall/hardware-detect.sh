#!/bin/bash
# Detects hardware for the TUI; prints shell variable assignments to be sourced.
# NVIDIA support is best-effort and untested on real hardware. Device ID
# thresholds match Omarchy and CachyOS chwd (0x1e00 Turing, 0x1340 Maxwell).

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
nvidia_legacy_580xx=false

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
                # Turing and newer: open kernel modules (required for RTX 50xx).
                gpu_packages="$gpu_packages linux-headers nvidia-open-dkms nvidia-utils lib32-nvidia-utils egl-wayland libva-nvidia-driver nvidia-settings opencl-nvidia lib32-opencl-nvidia lib32-vulkan-icd-loader"
                nvidia_proprietary_driver=true
            elif (( device_id >= 0x1340 )); then
                # Maxwell/Pascal/Volta: driver 590 dropped them, so use the 580xx
                # branch. It is AUR-only and built after archinstall; only its
                # official-repo dependencies go here.
                gpu_packages="$gpu_packages linux-headers dkms egl-wayland libva-nvidia-driver lib32-vulkan-icd-loader"
                nvidia_legacy_580xx=true
                nvidia_proprietary_driver=true
            else
                # Kepler and older: nouveau via mesa, only firmware and OpenCL needed.
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

# SMBIOS portable chassis types. Not a battery check: wireless peripherals
# also appear under /sys/class/power_supply.
laptop_packages=""
case "$(cat /sys/class/dmi/id/chassis_type 2>/dev/null || true)" in
    8|9|10|11|14|30|31|32)
        is_laptop=true
        laptop_packages="tlp tlp-pd tlp-rdw"
        ;;
    *) is_laptop=false ;;
esac

cat <<EOF
CPU_MICROCODE_PKG="$CPU_MICROCODE_PKG"
GPU_VENDORS="$gpu_vendors"
GPU_PACKAGES="$gpu_packages"
NVIDIA_PRESENT=$nvidia_present
NVIDIA_PROPRIETARY_DRIVER=$nvidia_proprietary_driver
NVIDIA_LEGACY_580XX=$nvidia_legacy_580xx
BLUETOOTH_DETECTED=$bluetooth_detected
IS_LAPTOP=$is_laptop
LAPTOP_PACKAGES="$laptop_packages"
EOF
