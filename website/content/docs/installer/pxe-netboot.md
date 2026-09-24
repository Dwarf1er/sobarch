+++
title = "PXE Netboot"
description = "Booting the installer over the network instead of from a USB drive."
weight = 70
template = "docs/page.html"

[extra]
lead = "The installer's boot artifacts are directly PXE-servable, no sobarch-specific changes needed. Sobarch documents the recipe; you bring the DHCP/TFTP server."
toc = true
+++

Sobarch doesn't run or host any PXE infrastructure itself, the same way
it doesn't host a package repository or any other network-facing
service. This page documents how to point your own DHCP/TFTP/HTTP setup
at the installer's own boot artifacts, so a machine can reach the
installer with nothing plugged in but a network cable.

## What you need

A working PXE boot needs three roles, all yours to run:

- **DHCP** (or a DHCP-adjacent proxy) telling the client where to find
  a network boot program.
- **TFTP and/or HTTP** serving that boot program, then the kernel,
  initramfs, and root filesystem image it chainloads.
- A place to put the actual boot artifacts (see below).

[Pixiecore](https://github.com/danderson/pixiecore) is the fastest way
to get all of the above running from one command against an existing
DHCP server, if you don't already have TFTP/DHCP infrastructure. A
classic `dnsmasq` (DHCP+TFTP) plus a plain HTTP server works just as
well if you do.

## Boot artifacts: either ISO works

Extract the boot artifacts from either the [official Arch Linux
ISO](https://archlinux.org/download/) or sobarch's own [prebuilt
monthly ISO](https://github.com/Dwarf1er/sobarch/releases); both use
the same archiso layout. Mount or extract the chosen ISO (`bsdtar -xf
<iso> arch/`, or a loop mount) and copy out:

- `arch/boot/x86_64/vmlinuz-linux`
- `arch/boot/x86_64/initramfs-linux.img`
- `arch/x86_64/airootfs.erofs` (or `.sfs`, depending on the release)

Serve those over HTTP. The kernel command line the client needs:

    archisobasedir=arch archiso_http_srv=http://<server>/<path>/ ip=dhcp verify=n

`verify=n` is required because the Arch ISO's checksum verification is
tied to Arch's own release signing, which a plain HTTP re-serving of
extracted files doesn't carry along. This is the same tradeoff any
PXE-netbooted archiso setup makes, sobarch-specific or not: you're
trusting the transport (your own local network), not re-deriving
Arch's own signature chain over it.

Sobarch's own ISO's `.automated_script.sh` checks for the same
`script=` kernel parameter the official ISO's does (see below), only
falling back to auto-launching the interactive TUI when it's absent,
so it works for unattended PXE installs too, with the added benefit of
its pre-cached package set. Prefer it unless you have a specific reason
to want an unmodified official image.

## Chaining into an unattended install

Either ISO's `.automated_script.sh` already does the one thing
PXE-driven automation needs: on login, it checks for a `script=`
kernel parameter, fetches whatever URL it names, and runs it. Add it to
the same command line as above:

    script=http://<server>/<path>/sobarch-pxe.sh

`sobarch-pxe.sh` is a small script you host yourself, not something
sobarch ships. It only needs to do what a human would otherwise type by
hand:

    #!/usr/bin/env bash
    curl -fsSL -o /tmp/answer.json http://<server>/<path>/answer.json
    curl -fsSL http://installsobarch.antoinepoulin.com | bash -s -- --answer-file /tmp/answer.json

See [Unattended Install](../unattended-install/) for the full answer
file schema. Use `password_hash` instead of `password` (and, if disk
encryption is enabled, keep in mind `encryption_password` still can't
be pre-hashed the same way, see the note below) so a plaintext login
password isn't sitting on your HTTP server at all.

## What this doesn't cover

- **The answer file is still fetched in plaintext HTTP** in the recipe
  above, same as the boot artifacts themselves. This is fine on a
  trusted, physically-controlled provisioning network (the same
  assumption most in-house PXE/kickstart setups make), less fine
  otherwise; put your answer-file server behind HTTPS if your network
  doesn't meet that bar.
- **`encryption_password` (disk encryption's LUKS passphrase) can't be
  pre-hashed the way a login password can.** `password_hash` closes the
  login-password exposure, but a LUKS passphrase has to be shipped as
  the real secret, `cryptsetup` needs the actual passphrase material,
  not a hash of it, so plaintext transport exposure for that one field
  specifically can't be engineered away by a schema change. If that's a
  problem for your network, don't enable disk encryption on a
  PXE-provisioned install until you've secured the transport.
- **One shared answer file across many machines** has no collision
  handling (no MAC-based hostname templating, for example); each
  machine currently needs its own answer file and its own `script=`
  target if hostnames need to differ.
