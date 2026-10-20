+++
title = "Hardware Detection"
description = "How CPU, GPU, Bluetooth, and laptops are detected before the install starts."
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
  | Maxwell / Pascal / Volta | The pinned `nvidia-580xx` driver branch, built from source during install |
  | Anything older | `nouveau` |

- **Bluetooth adapter presence** drives `archinstall`'s own Bluetooth
  setup (installing `bluez`/`bluez-utils` and enabling the service),
  so there's no separate toggle to hunt for.
- **Laptop chassis** (read from the firmware's chassis type: laptop,
  notebook, portable, convertible, tablet, and similar) adds `tlp`,
  `tlp-rdw`, and `tlp-pd` for power management. Desktops and virtual
  machines don't get them. After install, TLP and its power-profile
  daemon are enabled and `systemd-rfkill` is masked so it doesn't fight
  TLP over radio state. See [Battery life and power
  tuning](../../reference/faq/#what-about-battery-life-and-power-tuning).
- **T2 Macs** (Apple hardware whose model is one of the T2 models, read
  from the firmware) switch the kernel to `linux-t2` and add the T2
  audio, fan, Touch Bar, Touch ID and firmware packages. See [T2
  Macs](../t2-mac/).

## NVIDIA-specific setup

On hardware using a proprietary NVIDIA driver (the first two tiers
above; `nouveau` needs none of this), the installer additionally handles what
package installation alone can't: DRM modesetting, early module
loading in the initramfs, and enabling the suspend/hibernate services
proprietary NVIDIA needs. NVIDIA-specific Hyprland environment
variables are only deployed on NVIDIA systems; AMD/Intel installs
never see them.

This runs as its own step right after `archinstall` finishes but
before reboot, against the already-completed, still-mounted install,
rather than through `archinstall`'s own early `custom_commands` hook,
which runs before `/etc/fstab` even exists and has no error handling.
