#!/bin/bash
# NVIDIA early-KMS system configuration

set -euo pipefail

if [ "${NVIDIA_PROPRIETARY_DRIVER:-false}" != "true" ]; then
    echo "nvidia-setup.sh: no proprietary NVIDIA driver in use, nothing to do."
    exit 0
fi

echo "nvidia-setup.sh: configuring NVIDIA early KMS..."

# Enable DRM modesetting. Hyprland cannot use nvidia_drm for actual display output without this
mkdir -p /etc/modprobe.d
cat > /etc/modprobe.d/nvidia.conf <<'EOF'
options nvidia_drm modeset=1
EOF

# Force the NVIDIA modules to load early, during the initramfs stage,
# rather than the default late/on-demand loading udev would otherwise
# do. Needed for modeset=1 above to take effect from early boot.
mkdir -p /etc/mkinitcpio.conf.d
cat > /etc/mkinitcpio.conf.d/nvidia.conf <<'EOF'
MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
EOF

# The generic mkinitcpio "kms" hook auto-probes whatever DRM driver the
# current hardware needs, which is fine for AMD/Intel/nouveau, but can
# conflict with the explicit module list above for a proprietary
# driver. CachyOS's chwd does the same hook removal for both of its
# proprietary NVIDIA tiers.
cat > /etc/mkinitcpio.conf.d/nvidia-kms-hook.conf <<'EOF'
HOOKS=(${HOOKS[@]/kms/})
EOF

# The config file edits above do nothing until the initramfs image
# itself is rebuilt.
mkinitcpio -P

# NVIDIA's driver doesn't integrate with the kernel's generic
# suspend/resume handling the way fully in-kernel drivers (amdgpu,
# i915) do, so it ships its own systemd units for this instead.
# Without them enabled, resuming from suspend/hibernate on NVIDIA
# hardware is a well-known source of a black screen or a driver that
# doesn't come back properly. The unit files themselves already land
# on disk as part of nvidia-utils/nvidia-580xx-utils (already
# installed via GPU_PACKAGES); only enabling them is still needed.
systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service

echo "nvidia-setup.sh: done."
