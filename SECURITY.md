# Security Policy

## Reporting a vulnerability

Please do not open a public issue for a security problem. Use GitHub's
private reporting: on the repository's **Security** tab, choose **Report
a vulnerability**.

If you can't use GitHub's reporting, email **contact@antoinepoulin.com**
instead.

Include what you found, how to reproduce it, and which version or ISO you
used. This is a small, independent project, so replies are best-effort,
but a report is read and acknowledged.

## Supported versions

Fixes land on `master` and ship in the next monthly ISO. Older ISOs are
not patched; reinstalling from a current one, or running Update System,
brings you current.

## Scope

In scope: the installer, the first-boot and update scripts, the
`sobarch-*` packages, the build and signing workflows, and the website.

Vendored AUR packages are built from reviewed snapshots; a flaw in the
upstream software itself should be reported to that project. If a
vendored package's PKGBUILD is malicious or compromised, tell us.

How packages are vetted and how releases are signed is described at
[sobarch.antoinepoulin.com/docs/reference/trust/](https://sobarch.antoinepoulin.com/docs/reference/trust/).
