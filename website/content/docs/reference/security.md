+++
title = "Security"
description = "The default firewall, account lockdown, and SSH policy, and what isn't covered."
weight = 10
template = "docs/page.html"

[extra]
lead = "A default-drop firewall, a locked root account, and SSH off by default, applied once on first boot and never left to chance."
toc = true
+++

## Firewall

`nftables` is installed and enabled with a default-drop inbound
policy. Only loopback traffic, established/related connections (invalid
packets are dropped), ICMP echo requests, the ICMPv6 messages IPv6
needs to work (echo, neighbor and router discovery), and a couple of
named exceptions get through:

- **LocalSend** (`53317`, TCP and UDP): opened unconditionally, since
  it's a required package regardless of whether you've launched it
  yet.
- **SSH** (`22`): only if you enabled it during install; see below.

The forward chain is default-drop too; the output chain is
default-accept.

### Opening a port yourself

Add a rule inside `chain input` in `/etc/nftables.conf`:

```
tcp dport <port> accept
```

Use `udp dport` instead for a UDP port, then apply it with
`systemctl restart nftables` (it has no reload action, just a one-shot
apply of the config file on start).

## Account lockdown

The root account is locked unconditionally (`passwd -l root`),
regardless of whether SSH is enabled or how the base system was
installed. SSH is off unless you turned it on in the installer's SSH
option; when it is on, root login over SSH is explicitly disabled too,
on top of the account-level lock, so that guarantee doesn't depend on
SSH's own state.

Power actions (lock, suspend, reboot, shutdown) are granted to the
`wheel` group without a password prompt via a small polkit rule. This
exists because a manually-launched compositor session, with no display
manager session integration beyond `ly`'s own, can fail to resolve as
an "active session" to polkit and fall back to an admin password
prompt otherwise; a `wheel` member could already reach the same
actions through `sudo`, so this doesn't cross a new privilege boundary.

## Login keyring

The login screen's PAM stack is pointed at `oo7`, the Secret Service
provider sobarch uses, and its daemon is enabled for every user so
it's already running by the time you log in. This is what unlocks your
keyring automatically with your login password, so Chromium-based
browsers and other apps that store secrets through the Secret Service
don't hang waiting on an unlock prompt. Your keyring is only as strong
as your login password, as with any auto-unlocked keyring.

## How the baseline is applied

All of the above is applied once by a first-boot unit that starts when
the network comes up. Its marker file is written only after every step
succeeds, so a failure retries on the next connection rather than
leaving you half-configured, and you get a notification either way.
The firewall and polkit files are written once and then left alone:
editing them is safe, and updates never overwrite them. See
[Files & Logs](../files-and-logs/).

## Package builds

Vendored packages are built as a dedicated, login-less `sobarch-build`
system user, never as root or your own account, and only from
reviewed snapshots in the sobarch repository; see
[AUR & Custom Packages](../../packages/aur-and-custom/). The build
user has no `sudo` or `pacman` rights: dependencies are installed
beforehand by the root-side script, and only the final `pacman -U`
runs as root. The installed packages themselves are not sandboxed.

## What isn't covered

- **Encryption of everything.** Disk encryption is optional (a LUKS
  toggle in the installer's Disk step) and covers only the root
  partition; the boot partition and any rescue-media partition are
  never encrypted.
- **Personal file backup.** [Snapshots](../../installer/snapshots/)
  cover the root filesystem for rollback, not your own files; back
  those up with your own tools.
