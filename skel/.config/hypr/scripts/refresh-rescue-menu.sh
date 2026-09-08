#!/usr/bin/env bash
# Exposes refresh-rescue-iso.sh (installed at
# /usr/local/lib/sobarch/refresh-rescue-iso.sh by sobarch-scripts) as a
# user-invoked action: re-fetch a current Arch ISO and re-extract its
# kernel/initramfs onto the rescue partitions rescue-iso-setup.sh laid
# out at install time. A stale rescue ISO still boots and still works;
# this is the manual refresh path Phase 2 deferred here rather than
# making automatic.
#
# No confirmation prompt: same convention as setup-package-menu.sh,
# just a "starting" notification (this is a multi-hundred-MB download,
# unlike that script's usual case, so something visible while it runs
# matters more here) followed by success/failure. The one privileged
# step goes through pkexec, same PolicyKit path every other
# privileged action on this desktop already uses.
set -euo pipefail

REFRESH_RESCUE_ISO="/usr/local/lib/sobarch/refresh-rescue-iso.sh"

notify-send "sobarch: refresh rescue iso" "Fetching a current Arch ISO; this can take a while..."

result=0
pkexec "$REFRESH_RESCUE_ISO" || result=$?

if ((result != 0)); then
    notify-send -u critical "sobarch: refresh rescue iso" \
        "Refresh failed partway through; the rescue media may be in a mixed state. Check journalctl for pkexec's output."
else
    notify-send "sobarch: refresh rescue iso" "Rescue ISO refreshed."
fi
