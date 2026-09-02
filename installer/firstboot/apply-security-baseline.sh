#!/usr/bin/env bash
# Placeholder call site for the security baseline, which doesn't
# exist yet. Wired into the first-boot flow now, alongside the
# skel/package-install steps, so implementing it later only needs to
# fill in the body below; no further service or install_runner.py
# changes should be needed once it lands.
#
# Kept idempotent the same way as install-profile-packages.sh: MARKER
# is only written after success, so a failed run retries on the next
# boot instead of being silently skipped.

set -euo pipefail

MARKER="/var/lib/sobarch/security-baseline-applied"

mkdir -p "$(dirname "$MARKER")"

echo "sobarch-firstboot: security baseline not implemented yet; skipping."

touch "$MARKER"
