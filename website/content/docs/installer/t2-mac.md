+++
title = "T2 Macs"
description = "Installing sobarch next to macOS on an Intel Mac with the T2 security chip."
weight = 56
template = "docs/page.html"

[extra]
lead = "The ISO has a T2 boot entry, and the installer can replace one partition you made in macOS, leaving macOS and Apple's boot partition alone."
toc = true
+++

T2 Macs (2018-2020 MacBook Pro and Air, 2020 iMac, iMac Pro, 2018 Mac
mini, 2019 Mac Pro) need a patched kernel to use their built-in
keyboard, trackpad, SSD and audio. The [prebuilt ISO](../../getting-started/prebuilt-iso/)
ships that kernel (`linux-t2`, from the third-party `arch-mact2`
repository) next to the stock one. The [stock Arch ISO plus
command](../../getting-started/installation/) does not work on these Macs.

## 1. Prepare macOS

- In **Disk Utility**, add a **partition** (not a volume) to the internal
  disk and size it for Linux, at least 20GiB. Pick any format except
  APFS; ExFAT is fine. The installer replaces it, so its format doesn't
  matter, and it can't be resized later.
- Keep macOS installed for now: the installer extracts the Wi-Fi and
  Bluetooth firmware from it.
- In **macOS Recovery**, open **Startup Security Utility**, set Secure
  Boot to **No Security** and allow booting from external media.

## 2. Boot the ISO

Hold **Option** at startup and pick the orange **EFI Boot** entry. In the
GRUB menu choose **Sobarch installer for T2 Macs**; the first entry is the
stock kernel and the keyboard won't work with it.

The ISO extracts the Wi-Fi and Bluetooth firmware from macOS on its own
before the installer starts. If that fails (macOS already removed, or an
unsupported macOS version), use a wired or USB Ethernet connection.

## 3. Install into your partition

In the **Disk** step, each unmounted partition of at least 20GiB (other
than boot partitions, APFS volumes and Windows reserved or recovery
partitions) is listed as an extra choice, for example `replace
/dev/nvme0n1p3 "LINUX" (exfat, 60.0 GiB)`. Pick yours. The installer:

- deletes only that partition and recreates its space as its own 1GiB
  boot partition and a btrfs root. macOS and Apple's own boot partition
  are never touched.
- asks you to type the partition name (for example `nvme0n1p3`) to
  confirm.
- turns rescue media off; the rescue ISO boots the stock kernel.

Choose the first entry for the whole disk only if you want macOS gone.

## 4. Make Linux the default boot

After the install the Mac still boots macOS by default, and you have to
hold **Option** every time. Change the default once, either way:

- **From the startup picker:** restart, hold **Option** until the picker
  appears, then hold **Control** and select the Linux entry (the orange
  **EFI Boot**, not the macOS volume).
- **From macOS:** **System Settings → General → Startup Disk**, pick
  **EFI Boot**, and restart.

A macOS update resets the default to macOS; repeat the step afterward.
The entry is only labeled "EFI Boot". To give it a name, run this in
macOS (the install's boot partition is the 1GiB one next to your
macOS volume; find its name in Disk Utility):

```sh
IDENTIFIER=$(diskutil info <PARTITION NAME> | grep "Device Identifier" | cut -d: -f2 | xargs)
sudo diskutil mount $IDENTIFIER
bless --folder /Volumes/<PARTITION NAME>/EFI/BOOT --label "Sobarch"
```

See the [t2linux startup manager
guide](https://wiki.t2linux.org/guides/startup-manager/) for details.

## What gets configured

- The `linux-t2` kernel replaces `linux`, and the unsigned `arch-mact2`
  repository stays enabled so the kernel keeps updating. Anything that
  repository ships is trusted without signature checks.
- Fan control (`t2fanrd`), the Touch Bar (`tiny-dfr`), audio
  (`apple-t2-audio-config`) and the Wi-Fi/Bluetooth firmware fetcher
  (`apple-bcm-firmware-fetcher`).
- `t2-touchid`, bound to the account you create, with fingerprint auth
  on the lock screen only.
- Kernel parameters `intel_iommu=on iommu=pt pcie_ports=compat`, the T2
  keyboard modules in the initramfs (so a LUKS passphrase can be typed),
  and a `brcmfmac` option that keeps Wi-Fi working with `wpa_supplicant`.

If the firmware wasn't copied during install, use a wired connection and run `sudo apple-bcm-firmware-fetcher` while
macOS is still on the disk, or see the [t2linux
guide](https://wiki.t2linux.org/guides/wifi-bluetooth/).

## Touch ID

Touch ID unlocks the lock screen through the `t2-touchid` bridge. It is
not used at the login prompt: logging in with your password is what
unlocks the keyring, and a finger can't do that. Other limits:

- Only fingers enrolled in macOS work. Linux can't enroll or delete
  fingers.
- Your password is still needed at every login and after a reboot, for
  disk encryption and the keyring.
- If no finger is recognized, the T2 wants the macOS account password
  once since it last lost power: boot macOS, log in with the password,
  then boot Linux again. Rebooting Linux doesn't reset this.
- Check it with `fprintd-list $USER` and `fprintd-verify`.

## Not handled yet

- Hybrid graphics on the 15 and 16-inch MacBook Pros (the AMD GPU stays
  on and power use is higher than it needs to be).
- Suspend problems some models have; see the t2linux state page.
- Not yet tested on real hardware.
