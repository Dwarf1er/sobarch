+++
title = "What the Install Does"
description = "The sequence the installer runs after you confirm, and where to look when it fails."
weight = 25
template = "docs/page.html"

[extra]
lead = "archinstall lays down the base system, then sobarch's own steps run against the still-mounted result before you reboot."
toc = true
+++

After you confirm on the Install step (or an [unattended
run](../unattended-install/) starts), the installer does the following, in
order, and shows the output live in the same pane.

1. **`archinstall`** partitions the disk, installs the base packages, the
   Limine bootloader, NetworkManager, and the other services from the
   generated configuration. Its credentials file is deleted as soon as it
   exits, whether or not it succeeded.
2. **Base packages are built and installed** inside the new system:
   `sobarch-skel`, `sobarch-scripts`, `sobarch-limine-snapshots`, and the
   AUR packages the base system requires. This uses the same sync
   mechanism described under [Packages](../../packages/aur-and-custom/).
   On the [prebuilt ISO](../../getting-started/prebuilt-iso/) the cached
   builds are reused where their versions match.
3. **The NVIDIA legacy driver** is built here too, only on
   Maxwell/Pascal/Volta hardware; see [Hardware
   Detection](../hardware-detection/). It takes a while.
4. **Your choices are recorded** for first boot: the selected profile
   packages, the SSH flag, and the git identity.
5. **First-boot units are installed and enabled.** See [First
   Boot](../../getting-started/first-boot/).
6. **Setup scripts run inside the new system**, in this order: NVIDIA
   configuration (when it applies), [Snapper](../snapshots/) retention and
   the first snapshot, the Limine boot menu theme, the Plymouth boot
   splash theme, the [rescue media](../rescue-media/) download and boot
   entry (when enabled), and the `ly` login screen theme.
7. **The target is unmounted** and you are offered **Reboot now** or
   **Quit**.

These steps run after `archinstall` finishes rather than through its own
`custom_commands` hook, because that hook runs before `/etc/fstab` exists
and has no error handling.

## When something fails

A failing step stops the install and names the step. The complete log is
`install.log` in the output directory, `/root/sobarch-install/` by
default, alongside the generated `base.json`. Fix the cause (usually the
network) and run the installer again; it regenerates its configuration
every time.
