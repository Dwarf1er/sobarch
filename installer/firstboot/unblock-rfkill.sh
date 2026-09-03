#!/usr/bin/env bash
# Unblocks any rfkill-soft-blocked wireless radios. Some laptops
# persist a software rfkill block (e.g. a firmware/EC-level
# airplane-mode toggle) that carries over into a fresh install,
# leaving WiFi unavailable (`nmcli` reporting "sw disabled") until
# something unblocks it. Run once by sobarch-firstboot-rfkill.service
# (ConditionPathExists on MARKER below, same pattern as the other
# first-boot units, and ordered before NetworkManager.service so the
# radio is already unblocked by the time it tries to bring devices
# up), which also fixes the two network-dependent first-boot units
# (packages, security baseline) failing outright with no network on a
# machine that boots with WiFi soft-blocked.

set -euo pipefail

MARKER="/var/lib/sobarch/rfkill-unblocked"

mkdir -p "$(dirname "$MARKER")"

echo "sobarch-firstboot: unblocking any soft-blocked wireless radios..."
rfkill unblock all

touch "$MARKER"
