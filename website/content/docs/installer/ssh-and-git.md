+++
title = "SSH & Git Options"
description = "The optional SSH server, and the git identity and SSH key set up for your account."
weight = 45
template = "docs/page.html"

[extra]
lead = "Two small choices in the Options step: whether to run an SSH server, and what git should call you."
toc = true
+++

Both live in the **Options** step, next to the [rescue
media](../rescue-media/) toggle.

## SSH server

**Enable SSH** is off by default. Turning it on installs `openssh`, enables
`sshd` with a drop-in configuration that disables root login over SSH, and
opens a firewall exception for port 22. With it off, `sshd` is explicitly
disabled. Root login itself is locked either way. All of this is applied
at [first boot](../../getting-started/first-boot/), once the network is up,
and the policy is described in [Security](../../reference/security/).

## Git identity and SSH key

Enter a name and an email to have them set as your global
`user.name` and `user.email`. Both must be given, or both left blank to
skip; the email is checked for a plausible shape.

Whatever you choose, first boot also generates an **ed25519 SSH key** for
your account at `~/.ssh/id_ed25519` if you do not already have one, with no
passphrase. Add the public key, `~/.ssh/id_ed25519.pub`, to your git host.
Only SSH is set up: there is no HTTPS credential helper. The key is created
once; an existing key is never replaced.

The same fields exist in an [unattended](../unattended-install/) answer
file as `ssh_enabled`, `git_name`, and `git_email`.
