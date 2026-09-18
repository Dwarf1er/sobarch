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
policy. Only loopback traffic, established/related connections, ICMP
echo requests, and a couple of named exceptions get through:

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
screen; when it is on, root login over SSH is explicitly disabled too,
on top of the account-level lock, so that guarantee doesn't depend on
SSH's own state.

Power actions (lock, suspend, reboot, shutdown) are granted to the
`wheel` group without a password prompt via a small polkit rule. This
exists because a manually-launched compositor session, with no display
manager session integration beyond `ly`'s own, can fail to resolve as
an "active session" to polkit and fall back to an admin password
prompt otherwise; a `wheel` member could already reach the same
actions through `sudo`, so this doesn't cross a new privilege boundary.

## What isn't covered

- **Disk encryption.** The installer doesn't offer it; see
  [Disk & Account Setup](../../installer/disk-and-accounts/) for what
  it actually asks for.
- **Personal file backup.** [Snapshots](../../installer/snapshots/)
  cover the root filesystem for rollback, not your own files; back
  those up with your own tools.
