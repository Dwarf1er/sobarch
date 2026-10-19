#!/bin/bash
# T2 Mac configuration, run in the target chroot. SOBARCH_USERNAME is set by install_runner.py.

set -euo pipefail

usermod -aG video "$SOBARCH_USERNAME"
systemctl enable t2fanrd.service tiny-dfr.service

# The T2 keyboard and trackpad sit behind t2bce; the initramfs needs them for a LUKS passphrase.
cat > /etc/mkinitcpio.conf.d/apple-t2.conf <<'CONF'
MODULES+=(t2bce_core t2bce_dma t2bce_vhci usbhid hid_apple hid_generic xhci_pci xhci_hcd)
CONF

# wpa_supplicant 2.11 breaks brcmfmac without this.
cat > /etc/modprobe.d/brcmfmac.conf <<'CONF'
options brcmfmac feature_disable=0x82000
CONF

cat > /etc/t2fand.conf <<'CONF'
[Fan1]
low_temp=55
high_temp=75
speed_curve=linear
always_full_speed=false
CONF

LIMINE_CONF="/boot/EFI/BOOT/limine.conf"
T2_PARAMS="intel_iommu=on iommu=pt pcie_ports=compat"
if ! grep -q "intel_iommu=on" "$LIMINE_CONF"; then
    sed -i "/^[[:space:]]*cmdline:/ s/\$/ $T2_PARAMS/" "$LIMINE_CONF"
fi

mkinitcpio -P

echo "t2-setup.sh: done."
