+++
title = "Disk Encryption"
description = "Optional LUKS encryption of the root partition."
weight = 15
template = "docs/page.html"

[extra]
lead = "One toggle in the Disk step encrypts the root filesystem with LUKS. Everything the firmware and bootloader need to start stays readable."
toc = true
+++

In the **Disk** step, **Encrypt the root partition (LUKS)** reveals a
passphrase field and a confirmation field. The step stays flagged until
the passphrase is non-empty and both entries match. Encryption is off by
default.

## What is and is not encrypted

- **Encrypted:** the btrfs root partition, which holds `@`, `@home`, and
  `@snapshots`. That covers your files and every [snapshot](../snapshots/).
- **Not encrypted:** the EFI System Partition and the
  [rescue media](../rescue-media/) partitions. The firmware has to read
  the ESP to boot at all, and the rescue ISO is a public Arch image with
  nothing private on it.

You enter the passphrase at every boot to unlock the root partition.
There is no key file and no recovery key, so a forgotten passphrase means
the data cannot be recovered.

## Related behavior

- Works the same on a wiped disk and on a [dual-boot](../dual-boot/)
  free-space install.
- [Snapshot rollback](../snapshots/#restoring-a-snapshot-as-the-new-root)
  from a live ISO asks for the passphrase first, to unlock the disk.
- For an [unattended install](../unattended-install/), set
  `encryption_password` in the answer file; a non-empty value turns
  encryption on. The passphrase has to be supplied as the real secret, so
  protect the answer file accordingly.
- The generated `credentials.json` holds the passphrase in plaintext. The
  installer creates it readable by root only and deletes it as soon as
  `archinstall` finishes. If you use **Save configuration** (or
  `--dry-run`), that file is written to the output directory and stays
  there, so delete it when you are done.
