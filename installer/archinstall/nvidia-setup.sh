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

# Load the modules from the initramfs so modeset=1 applies from early boot.
mkdir -p /etc/mkinitcpio.conf.d
cat > /etc/mkinitcpio.conf.d/nvidia.conf <<'EOF'
MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
EOF

# The generic kms hook can conflict with the explicit proprietary module list.
cat > /etc/mkinitcpio.conf.d/nvidia-kms-hook.conf <<'EOF'
HOOKS=(${HOOKS[@]/kms/})
EOF

mkinitcpio -P

# Without these, resume from suspend/hibernate often leaves a black screen.
systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service

echo "nvidia-setup.sh: done."
