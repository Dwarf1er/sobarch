+++
title = "First Boot"
description = "What runs automatically the first time you log in."
weight = 20
template = "docs/page.html"

[extra]
lead = "A few things finish setting up after the installer hands off: some run at ordinary boot, others wait for your first network connection."
toc = true
+++

Five systemd units run once, each guarded by its own marker file so a
completed step never repeats:

- **Wireless radio unblock.** Runs before NetworkManager starts, in
  case a laptop's WiFi radio comes up soft-blocked by firmware.
- **Skel deployment.** Your account's dotfiles are populated from
  sobarch's defaults. This is the same mechanism that later powers
  **Update System** from the desktop menu; see
  [Updating Your System](../../desktop/updating-system/) for how it
  merges changes without clobbering your edits.
- **Git and SSH key.** An ed25519 SSH key is generated for your account
  if it has none, and the git name and email from the installer's
  Options step are set as your global git identity. See [SSH & Git
  Options](../../installer/ssh-and-git/).
- **Optional profile packages.** Whatever software profiles you picked
  during install get installed now, not during the install session
  itself; see [Software Profiles](../../installer/software-profiles/)
  for why.
- **Security baseline.** A default-drop firewall is written and
  enabled, and the root account is locked. See
  [Security](../../reference/security/) for the full policy.

The radio unblock, skel deployment, and git/SSH key units run at ordinary
boot and need nothing from you. Your new public key is at
`~/.ssh/id_ed25519.pub`.
The other two need network access (installing packages, and
installing/enabling SSH if you asked for it), and neither has a boot-time
trigger at all: a NetworkManager dispatcher script starts them every time
a connection comes up instead. On a fresh WiFi-only install there's no
saved connection yet, so in practice they run as soon as you connect for
the first time, which can be right after your first login rather than on
some later reboot. Each unit's marker file makes a repeat start an
instant no-op, so reconnecting later doesn't redo anything.

The package and security steps show desktop notifications as they go, and
a failure is reported the same way, naming the journal to check, for
example `journalctl -u sobarch-firstboot-packages.service`. A failed step
leaves its marker unwritten, so it retries on the next connection instead
of being skipped.

None of this needs any action from you.
