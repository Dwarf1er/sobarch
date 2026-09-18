+++
title = "Hardware Detection"
description = "How CPU, GPU, and Bluetooth are detected before the install starts."
weight = 20
template = "docs/page.html"

[extra]
lead = "Detection runs once on the live ISO, before archinstall is invoked, and feeds the installer's choices directly. Nothing here needs picking manually."
toc = true
+++

- **CPU vendor** picks the right microcode package
  (`intel-ucode`/`amd-ucode`).
- **GPU vendor** picks the right `mesa`/`vulkan-*` packages. AMD and
  Intel are fully supported. NVIDIA is best-effort, split by
  generation tier (PCI device ID) rather than left with no driver at
  all, mirroring what Omarchy and CachyOS do in their own install
  scripts:

  | GPU generation | Driver |
  | --- | --- |
  | Turing (RTX 20-series) and newer | `nvidia-open-dkms` |
  | Maxwell / Pascal / Volta | A pinned legacy driver branch |
  | Anything older | `nouveau` |

- **Bluetooth adapter presence** drives `archinstall`'s own Bluetooth
  setup (installing `bluez`/`bluez-utils` and enabling the service),
  so there's no separate toggle to hunt for.

## NVIDIA-specific setup

On detected NVIDIA hardware, the installer additionally handles what
package installation alone can't: DRM modesetting, early module
loading in the initramfs, and enabling the suspend/hibernate services
proprietary NVIDIA needs. NVIDIA-specific Hyprland environment
variables are only deployed on NVIDIA systems; AMD/Intel installs
never see them.

This runs as its own step right after `archinstall` finishes but
before reboot, against the already-completed, still-mounted install,
rather than through `archinstall`'s own early `custom_commands` hook,
which runs before `/etc/fstab` even exists and has no error handling.
